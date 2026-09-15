part of 'crm_store.dart';

/// All attendance dates use the centre's time zone, including browsers abroad.
DateTime tashkentDate(DateTime time) =>
    time.toUtc().add(const Duration(hours: 5));

/// The inverse of [tashkentDate]: a real instant for a given Tashkent
/// wall-clock date and time, regardless of the device's own time zone.
DateTime tashkentInstant(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
    ).subtract(const Duration(hours: 5));

int _minutesOfDay(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

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
      'score_awards',
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
      _pointTotals
        ..clear()
        ..addAll(fresh._pointTotals);
      _pointBaseline
        ..clear()
        ..addAll(fresh._pointBaseline);
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
    _pointTotals.clear();
    _pointBaseline.clear();
    scoreAwards.clear();
    // RLS narrows this to the pupil's own history, or to the groups a staff
    // member manages.
    final memberName = {for (final u in users) u.membershipId: u.name};
    final memberUser = {for (final u in users) u.membershipId: u.id};
    for (final row in await client!.from('score_awards').select()) {
      final studentId = memberUser[row['student_membership_id'].toString()];
      if (studentId == null) continue;
      scoreAwards.add(
        ScoreAward(
          id: row['id'].toString(),
          studentId: studentId,
          groupId: row['group_id']?.toString(),
          amount: (row['amount'] as num).toInt(),
          note: row['note']?.toString() ?? '',
          byName: memberName[row['created_by'].toString()] ?? 'Xodim',
          createdAt: DateTime.parse(row['created_at'].toString()).toLocal(),
        ),
      );
    }
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
          _pointTotals[row.key] = (row.value as num).toInt();
        }
      }
    } else {
      _pointTotals[activeUser.id] =
          (_studentRanks['coins'] as num?)?.toInt() ??
          localPointsOf(activeUser.id);
    }
    for (final id in _pointTotals.keys) {
      _pointBaseline[id] = localPointsOf(id);
    }
  }

  /// Points a pupil earned from lessons alone: 10 per attended lesson plus
  /// the score of every accepted homework.
  int lessonPointsOf(String userId) {
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

  List<ScoreAward> awardsOf(String userId) =>
      scoreAwards.where((a) => a.studentId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Staff-added rewards, as a positive number.
  int bonusPointsOf(String userId) => scoreAwards
      .where((a) => a.studentId == userId && a.amount > 0)
      .fold(0, (sum, a) => sum + a.amount);

  /// Staff-added penalties, as a negative number.
  int penaltyPointsOf(String userId) => scoreAwards
      .where((a) => a.studentId == userId && a.amount < 0)
      .fold(0, (sum, a) => sum + a.amount);

  int localPointsOf(String userId) =>
      lessonPointsOf(userId) + bonusPointsOf(userId) + penaltyPointsOf(userId);

  /// Adds a reward (positive) or a penalty (negative) with its reason.
  Future<void> addScoreAward({
    required String studentId,
    required String groupId,
    required int amount,
    required String note,
  }) async {
    if (!canManageGroup(groupId))
      throw StateError('Ball berishga ruxsat yo‘q.');
    if (amount == 0 || amount < -1000 || amount > 1000)
      throw ArgumentError('Ball -1000 va 1000 oralig‘ida bo‘lsin.');
    final student = studentById(studentId, groupId);
    final actor = activeUser;
    final temp = _newId();
    await _mutate<Map<String, dynamic>>(
      apply: () => scoreAwards.add(
        ScoreAward(
          id: temp,
          studentId: studentId,
          groupId: resolveId(groupId),
          amount: amount,
          note: note,
          byName: actor.name,
          createdAt: DateTime.now(),
        ),
      ),
      send: () => client!
          .from('score_awards')
          .insert({
            'organization_id': groupById(groupId).organizationId,
            'student_membership_id': int.parse(student.membershipId),
            'group_id': _serverId(groupId),
            'amount': amount,
            'note': note,
            'created_by': int.parse(actor.membershipId),
          })
          .select()
          .single(),
      reconcile: (row) {
        final index = scoreAwards.indexWhere((a) => a.id == temp);
        scoreAwards[index] = ScoreAward(
          id: row['id'].toString(),
          studentId: studentId,
          groupId: row['group_id']?.toString(),
          amount: (row['amount'] as num).toInt(),
          note: row['note']?.toString() ?? '',
          byName: actor.name,
          createdAt: DateTime.parse(row['created_at'].toString()).toLocal(),
        );
        _ids[temp] = row['id'].toString();
      },
    );
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

  HomeworkStatus? _homeworkStatusFor(String homeworkId, String studentId) =>
      results
          .where(
            (r) =>
                r.homeworkId == resolveId(homeworkId) &&
                r.studentId == studentId,
          )
          .firstOrNull
          ?.status;

  /// Share of scheduled lessons the group's students attended (present or
  /// late), averaged across students. `null` when there is nothing to show.
  double? groupAttendanceRate(String groupId) {
    final lessons = lessonsOf(
      groupId,
    ).where((l) => l.status != 'cancelled').toList();
    final groupStudents = studentsOf(groupId);
    if (lessons.isEmpty || groupStudents.isEmpty) return null;
    final attended = groupStudents.fold<int>(
      0,
      (sum, student) =>
          sum +
          lessons.where((lesson) {
            final status = attendance[lesson.id]?[student.id];
            return status == AttendanceStatus.present ||
                status == AttendanceStatus.late;
          }).length,
    );
    return attended * 100 / (lessons.length * groupStudents.length);
  }

  /// Share of homework the group's students got accepted, averaged across
  /// students. `null` when there is nothing to show.
  double? groupHomeworkRate(String groupId) {
    final homework = homeworksOf(groupId);
    final groupStudents = studentsOf(groupId);
    if (homework.isEmpty || groupStudents.isEmpty) return null;
    final accepted = groupStudents.fold<int>(
      0,
      (sum, student) =>
          sum +
          homework
              .where(
                (item) =>
                    _homeworkStatusFor(item.id, student.id) ==
                    HomeworkStatus.accepted,
              )
              .length,
    );
    return accepted * 100 / (homework.length * groupStudents.length);
  }

  /// Group ranking value: the total points its students have collected.
  int groupPointTotal(String groupId) =>
      studentsOf(groupId).fold(0, (sum, student) => sum + pointsOf(student.id));

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
    'lesson_start_time': group.lessonStartTime.isEmpty
        ? null
        : group.lessonStartTime,
    'lesson_end_time': group.lessonEndTime.isEmpty ? null : group.lessonEndTime,
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

  /// Whether `now` falls within the group's scheduled lesson day and time
  /// (when a lesson_start_time/lesson_end_time pair is not set, the day
  /// check still applies but there is no time-of-day restriction).
  bool isScheduledNow(StudyGroup group, {DateTime? now}) {
    final today = tashkentDate(now ?? DateTime.now());
    if (group.weekDays.isNotEmpty && !group.weekDays.contains(today.weekday))
      return false;
    if (group.lessonStartTime.isEmpty || group.lessonEndTime.isEmpty)
      return true;
    final minutesNow = today.hour * 60 + today.minute;
    return minutesNow >= _minutesOfDay(group.lessonStartTime) &&
        minutesNow <= _minutesOfDay(group.lessonEndTime);
  }

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
        isScheduledNow(group, now: now);
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
