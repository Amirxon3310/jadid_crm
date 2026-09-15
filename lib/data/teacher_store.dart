part of 'crm_store.dart';

/// All attendance dates use the centre's time zone, including browsers abroad.
DateTime tashkentDate(DateTime time) =>
    time.toUtc().add(const Duration(hours: 5));

extension TeacherStore on CrmStore {
  void startLiveUpdates() {
    if (!isOnline || !enableLiveUpdates || _liveChannel != null) return;
    final channel = client!.channel('learning-${activeUser.id}');
    for (final table in [
      'groups',
      'enrollments',
      'lessons',
      'attendance',
      'assignments',
      'assignment_results',
      'lesson_checkins',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'organization_id',
          value: activeUser.organizationId,
        ),
        callback: (_) => _scheduleLearningRefresh(),
      );
    }
    _liveChannel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed)
        _scheduleLearningRefresh();
    });
  }

  void _scheduleLearningRefresh() {
    if (_disposed) return;
    _liveTimer?.cancel();
    _liveTimer = Timer(const Duration(milliseconds: 700), () async {
      if (!await refreshInBackground() && !_disposed)
        _scheduleLearningRefresh();
    });
  }

  /// Fetch off-screen, then adopt one coherent snapshot only if no local edit
  /// started in the meantime. A remote response cannot overwrite a newer draft.
  Future<bool> refreshInBackground() async {
    if (!isOnline || _disposed) return true;
    if (_refreshing || _mutations.isBusy) return false;
    _refreshing = true;
    final version = _editVersion, userId = activeUser.id;
    final fresh = CrmStore.online(client, enableLiveUpdates: false);
    try {
      await fresh.load();
      if (_disposed ||
          _mutations.isBusy ||
          version != _editVersion ||
          client!.auth.currentUser?.id != userId)
        return false;
      final images = Map<String, Uint8List>.of(avatarImages),
          selfies = Map<String, Uint8List>.of(checkinImages);
      _CrmSnapshot(fresh).restore(this);
      avatarImages.addAll(images);
      checkinImages.addAll(selfies);
      _studentRanks = Map.of(fresh._studentRanks);
      _coinTotals
        ..clear()
        ..addAll(fresh._coinTotals);
      _coinBaseline
        ..clear()
        ..addAll(fresh._coinBaseline);
      _dashboardMetrics = fresh._dashboardMetrics;
      _profileFeaturesReady = fresh._profileFeaturesReady;
      notifyListeners();
      return true;
    } catch (_) {
      // Retain usable data during an outage. Reconnection triggers a fresh read.
      return true;
    } finally {
      fresh.dispose();
      _refreshing = false;
    }
  }

  Future<void> _loadTeacherWorkspace() async {
    checkins.clear();
    _coinTotals.clear();
    _coinBaseline.clear();
    if (activeRole != AppRole.student) {
      final rows = await client!.from('lesson_checkins').select();
      for (final row in rows) {
        final teacher = users
            .where(
              (u) => u.membershipId == row['teacher_membership_id'].toString(),
            )
            .firstOrNull;
        if (teacher == null) continue;
        checkins.add(
          LessonCheckin(
            lessonId: row['lesson_id'].toString(),
            teacherId: teacher.id,
            photoPath: row['photo_path'] as String,
            checkedAt: DateTime.parse(row['checked_at'] as String),
          ),
        );
      }
      final totals = await Future.wait(
        visibleGroups.map(
          (g) async => Map<String, dynamic>.from(
            await client!.rpc(
              'group_rankings',
              params: {'p_group_id': _serverId(g.id)},
            ),
          ),
        ),
      );
      for (final group in totals) {
        for (final row in group.entries) {
          _coinTotals[row.key] = (row.value as num).toInt();
        }
      }
    } else {
      _coinTotals[activeUser.id] =
          (_studentRanks['coins'] as num?)?.toInt() ??
          localCoinsOf(activeUser.id);
    }
    for (final id in _coinTotals.keys) {
      _coinBaseline[id] = localCoinsOf(id);
    }
  }

  int localCoinsOf(String userId) {
    final homework = results
        .where(
          (r) => r.studentId == userId && r.status == HomeworkStatus.accepted,
        )
        .fold(0, (sum, r) => sum + (r.score ?? 0));
    final attended = lessons
        .where((l) => l.status != 'cancelled')
        .where((l) {
          final value = attendance[l.id]?[userId];
          return value == AttendanceStatus.present ||
              value == AttendanceStatus.late;
        })
        .map((l) => l.id)
        .toSet()
        .length;
    return homework + attended * 10;
  }

  ({int groups, int students, int left, int graduates, double percent})
  get teacherMetrics {
    final ids = visibleGroups.map((g) => g.id).toSet();
    final enrolled = students.where((s) => ids.contains(s.groupId)).toList();
    final total = enrolled.map((s) => s.id).toSet().length;
    final graduates = enrolled
        .where((s) => s.completed)
        .map((s) => s.id)
        .toSet()
        .length;
    return (
      groups: ids.length,
      students: total,
      left: enrolled.where((s) => s.left).map((s) => s.id).toSet().length,
      graduates: graduates,
      percent: total == 0 ? 0 : graduates * 100 / total,
    );
  }

  void requireActiveGroup(String id) {
    if (!canManageGroup(id))
      throw StateError('Guruhni boshqarishga ruxsat yo‘q.');
    if (!groupById(id).active) throw StateError('Guruh faol emas.');
  }

  Map<String, dynamic> _groupValues(StudyGroup group) => {
    'organization_id': group.organizationId,
    'name': group.name,
    'course': group.course,
    'teacher_membership_id': group.teacherMembershipId.isEmpty
        ? null
        : int.parse(group.teacherMembershipId),
    'schedule_text': group.schedule,
    'room': group.room,
    'status': group.status,
    'week_days': group.weekDays,
  };

  Future<void> updateGroup(StudyGroup group) async {
    if (activeRole != AppRole.admin) throw StateError('Admin huquqi kerak.');
    await _mutate<void>(
      apply: () {
        final index = groups.indexWhere((g) => g.id == resolveId(group.id));
        if (index < 0) throw StateError('Guruh saqlanmadi.');
        groups[index] = group.copyWith(id: resolveId(group.id));
      },
      send: () async {
        await client!
            .from('groups')
            .update(_groupValues(group))
            .eq('id', _serverId(group.id))
            .select('id')
            .single();
      },
    );
  }

  Future<void> setEnrollmentStatus(
    String studentId,
    String groupId,
    String status,
  ) async {
    if (!canManageGroup(groupId))
      throw StateError('Guruhni boshqarishga ruxsat yo‘q.');
    if (!['active', 'completed', 'left'].contains(status))
      throw ArgumentError('Noto‘g‘ri holat.');
    await _mutate<void>(
      apply: () {
        final index = students.indexWhere(
          (s) => s.id == studentId && s.groupId == resolveId(groupId),
        );
        if (index < 0) throw StateError('O‘quvchi guruhga biriktirilmagan.');
        students[index] = students[index].copyWith(
          completed: status == 'completed',
          left: status == 'left',
        );
      },
      send: () async {
        await client!.rpc(
          'set_enrollment_status',
          params: {
            'p_enrollment_id': _serverId(
              studentById(studentId, groupId).enrollmentId,
            ),
            'p_status': status,
          },
        );
      },
    );
  }

  LessonCheckin? checkinFor(Lesson lesson, {String? teacherId}) => checkins
      .where(
        (c) =>
            c.lessonId == resolveId(lesson.id) &&
            c.teacherId == (teacherId ?? activeUser.id),
      )
      .firstOrNull;

  bool isCheckinDay(Lesson lesson, {DateTime? now}) {
    final group = groupById(lesson.groupId);
    final day = tashkentDate(lesson.startsAt),
        today = tashkentDate(now ?? DateTime.now());
    return activeRole == AppRole.teacher &&
        group.teacherId == activeUser.id &&
        group.active &&
        lesson.status != 'cancelled' &&
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day &&
        (group.weekDays.isEmpty || group.weekDays.contains(day.weekday));
  }

  bool canMarkLesson(Lesson lesson) =>
      activeRole == AppRole.admin ||
      (isCheckinDay(lesson) && checkinFor(lesson) != null);

  Future<void> checkInLesson(Lesson lesson, Uint8List bytes) async {
    if (!isCheckinDay(lesson))
      throw StateError(
        'Faqat bugungi belgilangan darsda davomat qilish mumkin.',
      );
    if (checkinFor(lesson) != null) return;
    if (bytes.length > 3145728 || bytes.length < 4)
      throw ArgumentError('Rasm hajmi 3 MB dan oshmasin.');
    final png =
        bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71;
    final jpeg = bytes[0] == 255 && bytes[1] == 216;
    if (!png && !jpeg) throw ArgumentError('JPG yoki PNG rasm kerak.');
    final actor = activeUser;
    final stamp = DateTime.now();
    var path =
        '${actor.id}/${resolveId(lesson.id)}/${stamp.microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
    await _mutate<void>(
      apply: () {
        if (!lessons.any((l) => l.id == resolveId(lesson.id)))
          throw StateError('Dars saqlanmadi.');
        checkins.add(
          LessonCheckin(
            lessonId: resolveId(lesson.id),
            teacherId: actor.id,
            photoPath: path,
            checkedAt: stamp,
          ),
        );
        checkinImages[path] = bytes;
      },
      send: () async {
        path =
            '${actor.id}/${resolveId(lesson.id)}/${stamp.microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
        await client!.storage
            .from('lesson-checkins')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: png ? 'image/png' : 'image/jpeg',
              ),
            );
        try {
          await client!.rpc(
            'check_in_lesson',
            params: {'p_lesson_id': _serverId(lesson.id), 'p_photo_path': path},
          );
        } catch (_) {
          unawaited(
            client!.storage
                .from('lesson-checkins')
                .remove([path])
                .then<void>((_) {}, onError: (Object _) {}),
          );
          rethrow;
        }
      },
    );
  }

  Future<String> checkinUrl(String path) async =>
      client!.storage.from('lesson-checkins').createSignedUrl(path, 300);
}
