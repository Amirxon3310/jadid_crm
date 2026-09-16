import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dashboard_metrics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/migration.dart';
import 'auth_service.dart';
import 'models.dart';
import 'student_portal.dart';
import 'optimistic_queue.dart';
part 'student_portal_store.dart';
part 'teacher_store.dart';

/// UI faqat shu sodda qatlam bilan ishlaydi. Demo rejim testlar uchun qolgan,
/// real ilova esa [CrmStore.online] orqali Supabase'dan foydalanadi.
class CrmStore extends ChangeNotifier {
  CrmStore()
    : client = null,
      enableLiveUpdates = false,
      newAccountClient = null;
  CrmStore.online(
    this.client, {
    this.enableLiveUpdates = true,
    this.newAccountClient,
  }) {
    users.clear();
    groups.clear();
    students.clear();
    lessons.clear();
    homeworks.clear();
    attendance.clear();
    results.clear();
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _mutations.dispose();
    _liveTimer?.cancel();
    if (_liveChannel != null) unawaited(client!.removeChannel(_liveChannel!));
    super.dispose();
  }

  int _temporaryId = 0;
  final _ids = <String, String>{};
  String _newId() => 'pending-${++_temporaryId}';
  String resolveId(String id) => _ids[id] ?? id;
  int _serverId(String id) => int.parse(resolveId(id));
  late final _mutations = OptimisticQueue<_CrmSnapshot>(
    capture: () => _CrmSnapshot(this),
    restore: (snapshot) => snapshot.restore(this),
    notify: notifyListeners,
  );
  AppUser _confirmedProfile(String id) =>
      _mutations.confirmed!.users.firstWhere((u) => u.id == id);
  Future<void> _mutate<T>({
    required void Function() apply,
    required Future<T> Function() send,
    void Function(T)? reconcile,
  }) {
    _editVersion++;
    if (!isOnline) {
      apply();
      notifyListeners();
      return Future.value();
    }
    return _mutations.run(apply: apply, send: send, reconcile: reconcile);
  }

  final SupabaseClient? client;

  /// Builds the throwaway client a new pupil's sign-up runs on, so creating
  /// an account never touches the admin's own session. Tests supply their
  /// own; in the app it is left null and a real one is made on demand.
  final SupabaseClient Function()? newAccountClient;
  final bool enableLiveUpdates;
  RealtimeChannel? _liveChannel;
  Timer? _liveTimer;
  bool _refreshing = false;
  int _editVersion = 0;
  bool get isOnline => client != null;
  AppRole activeRole = AppRole.teacher;
  final checkins = <LessonCheckin>[];
  final scoreAwards = <ScoreAward>[];
  final checkinImages = <String, Uint8List>{};
  final _pointTotals = <String, int>{};
  final _pointBaseline = <String, int>{};

  final users = <AppUser>[
    const AppUser(id: 'admin-1', name: 'Amirxon', role: AppRole.admin),
    const AppUser(
      id: 'teacher-1',
      name: 'Qo‘zivoy Karimov',
      role: AppRole.teacher,
    ),
    const AppUser(
      id: 'teacher-2',
      name: 'Dilnoza Rahimova',
      role: AppRole.teacher,
    ),
    const AppUser(id: 'student-1', name: 'Ali Karimov', role: AppRole.student),
  ];

  final groups = <StudyGroup>[
    const StudyGroup(
      id: 'g1',
      name: 'Xadra Kids N34',
      course: 'Robototexnika',
      teacherId: 'teacher-1',
      teacherName: 'Qo‘zivoy Karimov',
      schedule: 'Dushanba / Chorshanba / Juma, 15:00–16:30',
      room: '3-xona',
    ),
    const StudyGroup(
      id: 'g2',
      name: 'Web dasturlash W02',
      course: 'HTML va CSS',
      teacherId: 'teacher-1',
      teacherName: 'Qo‘zivoy Karimov',
      schedule: 'Seshanba / Payshanba, 17:00–18:30',
      room: '5-xona',
    ),
    const StudyGroup(
      id: 'g3',
      name: 'Scratch S03',
      course: 'Scratch',
      teacherId: 'teacher-2',
      teacherName: 'Dilnoza Rahimova',
      schedule: 'Seshanba / Payshanba / Shanba, 14:00–15:30',
      room: '2-xona',
    ),
  ];

  final students = <Student>[
    const Student(
      id: 'student-1',
      name: 'Ali Karimov',
      groupId: 'g1',
      phone: '+998 90 123 45 67',
    ),
    const Student(
      id: 'student-2',
      name: 'Madina Salimova',
      groupId: 'g1',
      phone: '+998 91 234 56 78',
    ),
    const Student(
      id: 'student-3',
      name: 'Aziz Rustamov',
      groupId: 'g1',
      phone: '+998 93 345 67 89',
    ),
    const Student(
      id: 'student-4',
      name: 'Zilola Akbarova',
      groupId: 'g1',
      phone: '+998 94 456 78 90',
    ),
    const Student(
      id: 'student-5',
      name: 'Sardor Alimov',
      groupId: 'g2',
      phone: '+998 95 567 89 01',
    ),
    const Student(
      id: 'student-6',
      name: 'Malika Sobirova',
      groupId: 'g2',
      phone: '+998 97 678 90 12',
    ),
    const Student(
      id: 'student-7',
      name: 'Javohir Olimov',
      groupId: 'g2',
      phone: '+998 98 789 01 23',
    ),
    const Student(
      id: 'student-8',
      name: 'Asad Nurmatov',
      groupId: 'g3',
      phone: '+998 99 890 12 34',
    ),
  ];

  late final lessons = <Lesson>[
    Lesson(
      id: 'l1',
      groupId: 'g1',
      topic: 'Elektr motorlar',
      startsAt: _today(15),
    ),
    Lesson(
      id: 'l2',
      groupId: 'g2',
      topic: 'HTML formalar',
      startsAt: _today(17),
    ),
    Lesson(
      id: 'l3',
      groupId: 'g3',
      topic: 'Takrorlash bloklari',
      startsAt: _today(14),
    ),
    Lesson(id: 'l4', groupId: 'g1', topic: 'Sensorlar', startsAt: _day(-2, 15)),
  ];

  final homeworks = <Homework>[
    Homework(
      id: 'h1',
      groupId: 'g1',
      title: 'Motor sxemasini chizing',
      description: 'Motor, batareya va tugmani ulash sxemasini chizing.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
    ),
    Homework(
      id: 'h2',
      groupId: 'g1',
      title: 'Sensorlarni takrorlash',
      description: '3 xil sensor nomi va vazifasini yozing.',
      dueDate: DateTime.now().add(const Duration(days: 4)),
    ),
  ];

  final Map<String, Map<String, AttendanceStatus>> attendance = {
    'l4': {
      'student-1': AttendanceStatus.present,
      'student-2': AttendanceStatus.present,
      'student-3': AttendanceStatus.late,
      'student-4': AttendanceStatus.absent,
    },
  };
  // lessonId -> studentId -> "HH:mm" the student actually arrived. Only set
  // for present/late; absent has no arrival time.
  final Map<String, Map<String, String>> attendanceTimes = {};

  final results = <HomeworkResult>[
    HomeworkResult(
      homeworkId: 'h1',
      studentId: 'student-1',
      answer: 'Sxemani daftarimga chizdim.',
      status: HomeworkStatus.submitted,
    ),
  ];

  AppUser get activeUser {
    if (isOnline) {
      final id = client!.auth.currentUser!.id;
      return users.firstWhere((user) => user.id == id);
    }
    return users.firstWhere((user) => user.role == activeRole);
  }

  List<AppUser> get teachers =>
      users.where((user) => user.role == AppRole.teacher).toList();
  List<AppUser> get groupStaff =>
      users.where((user) => user.role != AppRole.student).toList();

  List<StudyGroup> get visibleGroups => switch (activeRole) {
    AppRole.admin => groups,
    AppRole.teacher =>
      groups.where((group) => group.teacherId == activeUser.id).toList(),
    AppRole.student =>
      groups
          .where(
            (group) => students.any(
              (student) =>
                  student.id == activeUser.id && student.groupId == group.id,
            ),
          )
          .toList(),
  };

  List<Student> studentsOf(String groupId) {
    final studentIds = users
        .where((user) => user.role == AppRole.student)
        .map((user) => user.id)
        .toSet();
    return students
        .where(
          (student) =>
              student.groupId == resolveId(groupId) &&
              studentIds.contains(student.id),
        )
        .toList();
  }

  List<Lesson> lessonsOf(String groupId) =>
      lessons.where((lesson) => lesson.groupId == resolveId(groupId)).toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  List<Homework> homeworksOf(String groupId) => homeworks
      .where((homework) => homework.groupId == resolveId(groupId))
      .toList();
  StudyGroup groupById(String id) =>
      groups.firstWhere((group) => group.id == resolveId(id));
  Student studentById(String id, String groupId) => students.firstWhere(
    (student) => student.id == id && student.groupId == resolveId(groupId),
  );

  HomeworkResult resultFor(String homeworkId, String studentId) {
    return results.firstWhere(
      (result) =>
          result.homeworkId == resolveId(homeworkId) &&
          result.studentId == studentId,
      orElse: () {
        final result = HomeworkResult(
          homeworkId: resolveId(homeworkId),
          studentId: studentId,
        );
        results.add(result);
        return result;
      },
    );
  }

  /// RLS har bir rolga faqat ruxsat berilgan yozuvlarni qaytaradi.
  Future<void> load() async {
    if (!isOnline) return;
    final database = client!;
    final profileRows = List<Map<String, dynamic>>.from(
      await database.from('profiles').select(),
    );
    final membershipRows = List<Map<String, dynamic>>.from(
      await database.from('memberships').select(),
    );
    _profileFeaturesReady =
        profileRows.isNotEmpty &&
        profileRows.first.containsKey('first_name') &&
        membershipRows.isNotEmpty &&
        membershipRows.first.containsKey('study_status');
    final profileById = {
      for (final row in profileRows) row['id'].toString(): row,
    };

    users
      ..clear()
      ..addAll(
        membershipRows.map((row) {
          final profile =
              profileById[row['profile_id'].toString()] ??
              const <String, dynamic>{};
          return AppUser(
            id: row['profile_id'].toString(),
            membershipId: row['id'].toString(),
            organizationId: row['organization_id'].toString(),
            name: (profile['full_name'] ?? 'Foydalanuvchi').toString(),
            phone: (profile['phone'] ?? '').toString(),
            role: _role(row['role'].toString()),
            firstName: (profile['first_name'] ?? '').toString(),
            lastName: (profile['last_name'] ?? '').toString(),
            age: profile['age'] as int?,
            gender: profile['gender'] as String?,
            branch: (profile['branch'] ?? '').toString(),
            contactEmail: (profile['contact_email'] ?? '').toString(),
            avatarPath: profile['avatar_path'] as String?,
            studyStatus: (row['study_status'] ?? 'studying').toString(),
            graduatedAt: DateTime.tryParse(
              (row['graduated_at'] ?? '').toString(),
            )?.toLocal(),
            createdAt: DateTime.tryParse(
              (profile['created_at'] ?? '').toString(),
            )?.toLocal(),
          );
        }),
      );
    activeRole = activeUser.role;

    final userByMembership = {
      for (final user in users) user.membershipId: user,
    };
    final groupRows = List<Map<String, dynamic>>.from(
      await database.from('groups').select(),
    );
    groups
      ..clear()
      ..addAll(
        groupRows.map((row) {
          final teacher =
              userByMembership[row['teacher_membership_id']?.toString()];
          return StudyGroup(
            id: row['id'].toString(),
            organizationId: row['organization_id'].toString(),
            name: row['name'].toString(),
            course: row['course'].toString(),
            teacherId: teacher?.id ?? '',
            teacherMembershipId: teacher?.membershipId ?? '',
            teacherName: teacher?.name ?? 'Ustoz biriktirilmagan',
            schedule: row['schedule_text'].toString(),
            room: row['room'].toString(),
            status: row['status'] as String? ?? 'active',
            weekDays: List<int>.from(row['week_days'] as List? ?? []),
            totalLessons: row['total_lessons'] as int?,
            startsOn: _instant(row['starts_on']),
            lessonStartTime: _shortTime(row['lesson_start_time'] as String?),
            lessonEndTime: _shortTime(row['lesson_end_time'] as String?),
          );
        }),
      );

    final enrollmentRows = List<Map<String, dynamic>>.from(
      await database.from('enrollments').select(),
    );
    final enrollmentById = <String, Student>{};
    students.clear();
    for (final row in enrollmentRows) {
      final user = userByMembership[row['student_membership_id'].toString()];
      if (user == null) continue;
      final student = Student(
        id: user.id,
        membershipId: user.membershipId,
        enrollmentId: row['id'].toString(),
        completed:
            row['study_status'] == 'completed' ||
            (row['study_status'] == null && row['ends_on'] != null),
        left: row['study_status'] == 'left',
        frozen: row['study_status'] == 'frozen',
        name: user.name,
        phone: user.phone,
        groupId: row['group_id'].toString(),
        enrolledFrom: DateTime.tryParse(row['starts_on']?.toString() ?? ''),
        enrolledUntil: DateTime.tryParse(row['ends_on']?.toString() ?? ''),
      );
      students.add(student);
      enrollmentById[student.enrollmentId] = student;
    }
    for (final user in users.where((item) => item.role == AppRole.student)) {
      if (students.every((student) => student.id != user.id)) {
        students.add(
          Student(
            id: user.id,
            membershipId: user.membershipId,
            name: user.name,
            phone: user.phone,
            groupId: '',
          ),
        );
      }
    }

    final lessonRows = List<Map<String, dynamic>>.from(
      await database.from('lessons').select(),
    );
    lessons
      ..clear()
      ..addAll(
        lessonRows.map(
          (row) => Lesson(
            id: row['id'].toString(),
            groupId: row['group_id'].toString(),
            topic: row['topic'].toString(),
            startsAt: DateTime.parse(row['starts_at'].toString()).toLocal(),
            status: row['status'] as String? ?? 'planned',
          ),
        ),
      );

    final assignmentRows = List<Map<String, dynamic>>.from(
      await database.from('assignments').select(),
    );
    homeworks
      ..clear()
      ..addAll(assignmentRows.map(_homeworkFrom));

    attendance.clear();
    attendanceTimes.clear();
    final attendanceRows = List<Map<String, dynamic>>.from(
      await database.from('attendance').select(),
    );
    for (final row in attendanceRows) {
      final student = enrollmentById[row['enrollment_id'].toString()];
      if (student == null) continue;
      final lessonId = row['lesson_id'].toString();
      attendance.putIfAbsent(lessonId, () => {})[student.id] = _attendance(
        row['status'].toString(),
      );
      final arrivedAt = row['arrived_at'] as String?;
      if (arrivedAt != null) {
        attendanceTimes.putIfAbsent(lessonId, () => {})[student.id] = arrivedAt
            .substring(0, 5);
      }
    }

    results.clear();
    final resultRows = List<Map<String, dynamic>>.from(
      await database.from('assignment_results').select(),
    );
    for (final row in resultRows) {
      final student = enrollmentById[row['enrollment_id'].toString()];
      if (student == null) continue;
      results.add(
        HomeworkResult(
          homeworkId: row['assignment_id'].toString(),
          studentId: student.id,
          answer: row['answer'].toString(),
          status: _homework(row['status'].toString()),
          score: row['score'] as int?,
          comment: row['comment'].toString(),
          files: HomeworkFile.listFrom(row, 'files'),
          reviewFiles: HomeworkFile.listFrom(row, 'review_files'),
          submittedAt: _instant(row['submitted_at']),
          reviewedAt: _instant(row['reviewed_at']),
          resubmitAllowed: row['resubmit_allowed'] as bool? ?? true,
        ),
      );
    }
    _homeworkReviewReady = await _hasColumn(
      'assignment_results',
      'review_files',
    );
    _groupPlanReady = await _hasColumn('groups', 'total_lessons');
    _dashboardMetrics = null;
    if (activeRole == AppRole.admin && _profileFeaturesReady) {
      _dashboardMetrics = DashboardMetrics.fromJson(
        Map<String, dynamic>.from(
          await database.rpc(
            'dashboard_metrics',
            params: {'p_organization_id': activeUser.organizationId},
          ),
        ),
      );
    }
    await _loadStudentPortal();
    await _loadTeacherWorkspace();
    // After the workspace, which clears the point totals before filling in
    // its own: a classmate's total would otherwise be wiped on the way past.
    await _loadClassmates();
    avatarUrls.clear();
    final paths = users
        .where((u) => u.avatarPath != null)
        .map((u) => u.avatarPath!)
        .toSet()
        .toList();
    if (paths.isNotEmpty) {
      try {
        final urls = await database.storage
            .from('profile-avatars')
            .createSignedUrlsResult(paths, 86400);
        for (final item in urls) {
          if (item is SignedUrlSuccess) avatarUrls[item.path] = item.signedUrl;
        }
      } catch (_) {
        /* Profile text remains available if image retrieval fails. */
      }
    }
    notifyListeners();
  }

  void changeRole(AppRole role) {
    if (isOnline) return;
    activeRole = role;
    notifyListeners();
  }

  Future<void> saveAttendance(
    String lessonId,
    Map<String, AttendanceStatus> values, {
    Map<String, String?> times = const {},
  }) async {
    final groupId = lessons
        .firstWhere((l) => l.id == resolveId(lessonId))
        .groupId;
    final changes = Map<String, AttendanceStatus>.of(values);
    // Absent has no arrival time even if one was entered before switching.
    String? arrivalOf(String studentId) =>
        changes[studentId] == AttendanceStatus.absent ? null : times[studentId];
    if (!canManageGroup(groupId))
      throw StateError('Davomatni belgilashga ruxsat yo‘q.');
    for (final id in changes.keys) {
      studentById(id, groupId);
    }
    final actor = activeUser;
    await _mutate<void>(
      apply: () {
        final id = resolveId(lessonId);
        if (!lessons.any((l) => l.id == id))
          throw StateError('Dars saqlanmadi.');
        if (isOnline && !canMarkLesson(lessons.firstWhere((l) => l.id == id)))
          throw StateError('Avval bugungi dars uchun suratga tushing.');
        if (activeRole == AppRole.teacher &&
            changes.keys.any((s) => !studentById(s, groupId).active))
          throw StateError('Faqat aktiv o‘quvchi davomatini belgilang.');
        attendance.putIfAbsent(id, () => {}).addAll(changes);
        final lessonTimes = attendanceTimes.putIfAbsent(id, () => {});
        for (final studentId in changes.keys) {
          final arrival = arrivalOf(studentId);
          if (arrival == null) {
            lessonTimes.remove(studentId);
          } else {
            lessonTimes[studentId] = arrival;
          }
        }
      },
      send: () async {
        if (changes.isEmpty) return;
        await client!
            .from('attendance')
            .upsert(
              changes.entries
                  .map(
                    (entry) => {
                      'organization_id': groupById(groupId).organizationId,
                      'lesson_id': _serverId(lessonId),
                      'enrollment_id': _serverId(
                        studentById(entry.key, groupId).enrollmentId,
                      ),
                      'status': entry.value.name,
                      'arrived_at': arrivalOf(entry.key),
                      'marked_by': int.parse(actor.membershipId),
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    },
                  )
                  .toList(),
              onConflict: 'lesson_id,enrollment_id',
            );
      },
    );
  }

  Future<void> addHomework(
    String groupId,
    String title,
    String description,
    DateTime dueDate, {
    String? lessonId,
    List<PickedFile> files = const [],
  }) async {
    final temp = _newId();
    final actor = activeUser;
    if (files.isNotEmpty && !homeworkReviewReady) throw homeworkReviewMigration;
    final givenAt = DateTime.now();
    await _mutate<Map<String, dynamic>>(
      apply: () {
        final group = groupById(groupId);
        requireActiveGroup(groupId);
        if (lessonId != null &&
            !lessons.any(
              (l) =>
                  l.id == resolveId(lessonId) &&
                  l.groupId == group.id &&
                  l.status != 'cancelled',
            ))
          throw StateError('Darsni tanlang.');
        homeworks.add(
          Homework(
            id: temp,
            groupId: group.id,
            title: title,
            description: description,
            dueDate: dueDate,
            lessonId: lessonId == null ? null : resolveId(lessonId),
            createdAt: givenAt,
            files: _pendingFiles(files),
          ),
        );
      },
      send: () async {
        final uploaded = await _uploadHomeworkFiles(groupId, 'tasks', files);
        try {
          return await _homeworkWrite(
            () => client!
                .from('assignments')
                .insert({
                  'organization_id': groupById(groupId).organizationId,
                  'group_id': _serverId(groupId),
                  'title': title,
                  'description': description,
                  'due_at': dueDate.toUtc().toIso8601String(),
                  'lesson_id': lessonId == null ? null : _serverId(lessonId),
                  'created_by': int.parse(actor.membershipId),
                  // Only sent when there is something to send, so a plain
                  // homework still saves before the files migration runs.
                  if (uploaded.isNotEmpty)
                    'files': [for (final file in uploaded) file.toJson()],
                })
                .select()
                .single(),
          );
        } catch (_) {
          _removeHomeworkFiles(uploaded);
          rethrow;
        }
      },
      reconcile: (row) {
        final saved = _homeworkFrom(row);
        homeworks[homeworks.indexWhere(
          (h) => h.id == temp,
        )] = saved.createdAt == null
            ? saved.copyWith(createdAt: givenAt)
            : saved;
        _ids[temp] = row['id'].toString();
      },
    );
  }

  /// Changes what a homework asks for, when it is due, and which files come
  /// with it. A file taken off is deleted from the bucket once the row has
  /// been updated, so a failed save never loses it.
  Future<void> updateHomework(
    String homeworkId, {
    required String title,
    required DateTime dueDate,
    List<PickedFile> addedFiles = const [],
    List<HomeworkFile> removedFiles = const [],
  }) async {
    final text = title.trim();
    if (text.isEmpty) throw ArgumentError('Vazifani yozing.');
    final homework = homeworks.firstWhere((h) => h.id == resolveId(homeworkId));
    if (!canManageGroup(homework.groupId))
      throw StateError('Vazifani tahrirlashga ruxsat yo‘q.');
    if ((addedFiles.isNotEmpty || removedFiles.isNotEmpty) &&
        !homeworkReviewReady)
      throw homeworkReviewMigration;
    final gone = {for (final file in removedFiles) file.path};
    final kept = [
      for (final file in homework.files)
        if (!gone.contains(file.path)) file,
    ];
    await _mutate<List<HomeworkFile>>(
      apply: () {
        final index = homeworks.indexWhere(
          (h) => h.id == resolveId(homeworkId),
        );
        if (index < 0) throw StateError('Vazifa topilmadi.');
        homeworks[index] = homeworks[index].copyWith(
          title: text,
          dueDate: dueDate,
          files: [...kept, ..._pendingFiles(addedFiles)],
        );
      },
      send: () async {
        final uploaded = await _uploadHomeworkFiles(
          homework.groupId,
          'tasks',
          addedFiles,
        );
        final files = [...kept, ...uploaded];
        try {
          await _homeworkWrite(
            () => client!
                .from('assignments')
                .update({
                  'title': text,
                  'due_at': dueDate.toUtc().toIso8601String(),
                  if (addedFiles.isNotEmpty || removedFiles.isNotEmpty)
                    'files': [for (final file in files) file.toJson()],
                })
                .eq('id', _serverId(homeworkId))
                .select('id')
                .single(),
          );
        } catch (_) {
          _removeHomeworkFiles(uploaded);
          rethrow;
        }
        // Only now, with the row saved, does the old file go.
        _removeHomeworkFiles(removedFiles);
        return files;
      },
      reconcile: (files) {
        final index = homeworks.indexWhere(
          (h) => h.id == resolveId(homeworkId),
        );
        if (index >= 0)
          homeworks[index] = homeworks[index].copyWith(files: files);
      },
    );
  }

  /// Deletes a homework together with every answer and review to it.
  Future<void> deleteHomework(String homeworkId) async {
    final homework = homeworks.firstWhere((h) => h.id == resolveId(homeworkId));
    if (!canManageGroup(homework.groupId))
      throw StateError('Vazifani o‘chirishga ruxsat yo‘q.');
    if (!homeworkReviewReady) throw homeworkReviewMigration;
    final attached = [
      ...homework.files,
      for (final result in results.where(
        (r) => r.homeworkId == homework.id,
      )) ...[...result.files, ...result.reviewFiles],
    ];
    await _mutate<void>(
      apply: () {
        homeworks.removeWhere((h) => h.id == resolveId(homeworkId));
        results.removeWhere((r) => r.homeworkId == resolveId(homeworkId));
      },
      send: () async {
        final removed = await client!
            .from('assignments')
            .delete()
            .eq('id', _serverId(homeworkId))
            .select('id');
        // Row security hides a refused delete: nothing comes back and
        // nothing is removed.
        if (removed.isEmpty)
          throw StateError('Vazifani o‘chirishga ruxsat yo‘q.');
        _removeHomeworkFiles(attached);
      },
    );
  }

  Homework _homeworkFrom(Map<String, dynamic> row) => Homework(
    id: row['id'].toString(),
    groupId: row['group_id'].toString(),
    title: row['title'].toString(),
    description: (row['description'] ?? '').toString(),
    dueDate: DateTime.parse(row['due_at'].toString()).toLocal(),
    lessonId: row['lesson_id']?.toString(),
    createdAt: _instant(row['created_at']),
    files: HomeworkFile.listFrom(row, 'files'),
  );

  static DateTime? _instant(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  /// Names shown while the files are still uploading; no path yet.
  static List<HomeworkFile> _pendingFiles(List<PickedFile> files) => [
    for (final file in files) HomeworkFile(path: '', name: file.name),
  ];

  /// Uploads into `<org>/<group>/<folder>/`. A failure part-way removes what
  /// did go up, so a half-sent answer leaves nothing behind.
  Future<List<HomeworkFile>> _uploadHomeworkFiles(
    String groupId,
    String folder,
    List<PickedFile> files,
  ) async {
    final uploaded = <HomeworkFile>[];
    if (files.isEmpty) return uploaded;
    final base =
        '${groupById(groupId).organizationId}/${_serverId(groupId)}/$folder';
    try {
      for (final (index, file) in files.indexed) {
        // Storage keys refuse spaces and most non-Latin letters.
        final safe = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final path =
            '$base/${DateTime.now().microsecondsSinceEpoch}_${index}_$safe';
        await client!.storage
            .from('homework-files')
            .uploadBinary(path, file.bytes);
        uploaded.add(HomeworkFile(path: path, name: file.name));
      }
    } catch (_) {
      _removeHomeworkFiles(uploaded);
      rethrow;
    }
    return uploaded;
  }

  void _removeHomeworkFiles(List<HomeworkFile> files) {
    final paths = [
      for (final file in files)
        if (file.path.isNotEmpty) file.path,
    ];
    if (paths.isEmpty || !isOnline) return;
    unawaited(
      client!.storage
          .from('homework-files')
          .remove(paths)
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Whether [column] exists. Selecting a column a table lacks is the one
  /// unambiguous sign of a migration not applied: PostgREST answers 42703.
  Future<bool> _hasColumn(String table, String column) async {
    try {
      await client!.from(table).select(column).limit(1);
      return true;
    } on PostgrestException catch (error) {
      return error.code != '42703' && error.code != 'PGRST204';
    }
  }

  /// A safety net behind [homeworkReviewReady], for a database changed after
  /// it loaded: the errors only a missing migration gives become the notice
  /// that hands over its SQL. A permission refusal (42501) is left alone —
  /// it means the same whether or not the migration ran.
  static Future<T> _homeworkWrite<T>(Future<T> Function() write) async {
    try {
      return await write();
    } on PostgrestException catch (error) {
      // PGRST204 / 42703: no such column. 23514: the old 1–5 score check —
      // scores are held to 0–100 before sending, so nothing else trips it.
      if (const {'PGRST204', '42703', '23514'}.contains(error.code)) {
        throw homeworkReviewMigration;
      }
      rethrow;
    }
  }

  /// A pupil sees no one else's enrolment, so the group list and the rating
  /// board would show them alone. The server hands over exactly what those
  /// two need — who is in the group, their avatar, their state and their
  /// points — and nothing else about them.
  Future<void> _loadClassmates() async {
    classmateResults.clear();
    if (activeRole != AppRole.student) return;
    for (final group in visibleGroups) {
      final List<dynamic> rows;
      try {
        rows = await client!.rpc(
          'group_classmates',
          params: {'p_group_id': _serverId(group.id)},
        );
      } on PostgrestException catch (error) {
        // PGRST202: the function is not there yet. Remember it, so the group
        // page can hand over the SQL rather than look empty for no reason.
        if (error.code == 'PGRST202') {
          _classmatesReady = false;
          return;
        }
        rethrow;
      }
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final id = row['profile_id'].toString();
        final name = (row['full_name'] ?? 'O‘quvchi').toString();
        final status = (row['study_status'] ?? 'active').toString();
        if (!users.any((u) => u.id == id)) {
          users.add(
            AppUser(
              id: id,
              membershipId: row['membership_id'].toString(),
              organizationId: group.organizationId,
              name: name,
              role: AppRole.student,
              avatarPath: row['avatar_path'] as String?,
            ),
          );
        }
        if (!students.any((s) => s.id == id && s.groupId == group.id)) {
          students.add(
            Student(
              id: id,
              name: name,
              groupId: group.id,
              phone: '',
              membershipId: row['membership_id'].toString(),
              enrollmentId: row['enrollment_id'].toString(),
              completed: status == 'completed',
              left: status == 'left',
              frozen: status == 'frozen',
            ),
          );
        }
        // Their total comes from the server; none of the attendance or
        // homework behind it is readable here, so the baseline matches.
        int part(String key) => (row[key] as num?)?.toInt() ?? 0;
        classmateResults[id] = (
          homework: part('homework_points'),
          attendance: part('attendance_points'),
          reward: part('reward_points'),
          penalty: part('penalty_points'),
        );
        _pointTotals[id] = (row['points'] as num?)?.toInt() ?? 0;
        _pointBaseline[id] = localPointsOf(id);
      }
    }
  }

  /// Replaces an account's password. Only an admin may, and the server
  /// decides that. The old one cannot be read back — only its hash is kept —
  /// so this replaces rather than reveals.
  Future<void> setAccountPassword(String userId, String password) async {
    if (activeRole != AppRole.admin) throw StateError('Admin huquqi kerak.');
    if (!isOnline) throw UnsupportedError('Faqat serverda ishlaydi.');
    if (password.trim().length < 4) {
      throw ArgumentError('Parol kamida 4 ta belgidan iborat bo‘lsin.');
    }
    try {
      await client!.rpc(
        'set_account_password',
        params: {'p_profile_id': userId, 'p_password': password},
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        throw StateError(
          'Parolni almashtirish uchun bazada set_account_password funksiyasi '
          'kerak: 20260918140000_account_admin.sql ni ishga tushiring.',
        );
      }
      throw ArgumentError(error.message);
    }
  }

  /// The login an account signs in with. Only an admin may ask, and the
  /// server decides that. A password cannot be read at all — only its hash
  /// is stored — so there is nothing of the sort here.
  Future<String?> memberLogin(String userId) async {
    if (!isOnline) return null;
    try {
      final value = await client!.rpc(
        'member_login',
        params: {'p_profile_id': userId},
      );
      return value as String?;
    } catch (_) {
      // Showing the login is a convenience — not deployed, not permitted or
      // simply unreachable must never break the profile it sits on.
      return null;
    }
  }

  Future<String> homeworkFileUrl(String path) async =>
      client!.storage.from('homework-files').createSignedUrl(path, 300);

  Future<void> submitHomework(
    String homeworkId,
    String studentId,
    String answer, {
    List<PickedFile> files = const [],
  }) async {
    final homework = homeworks.firstWhere((h) => h.id == resolveId(homeworkId));
    if (!studentById(studentId, homework.groupId).active ||
        !groupById(homework.groupId).active)
      throw StateError('Bu guruhdagi o‘qish tugagan.');
    final current = resultFor(homeworkId, studentId);
    if (current.status == HomeworkStatus.accepted) {
      throw StateError('Qabul qilingan javobni o‘zgartirib bo‘lmaydi.');
    }
    if (current.status == HomeworkStatus.returned && !current.resubmitAllowed) {
      throw StateError('Ustoz bu vazifani qayta yuborishga ruxsat bermagan.');
    }
    if (answer.trim().isEmpty && files.isEmpty && current.files.isEmpty)
      throw ArgumentError('Izoh yozing yoki fayl biriktiring.');
    if (files.isNotEmpty && !homeworkReviewReady) throw homeworkReviewMigration;
    // A resubmission clears the old review, its files included.
    final clearReviewFiles = current.reviewFiles.isNotEmpty;
    final sentAt = DateTime.now();
    await _mutate<List<HomeworkFile>>(
      apply: () {
        if (!homeworks.any((h) => h.id == resolveId(homeworkId)))
          throw StateError('Vazifa saqlanmadi.');
        final result = resultFor(homeworkId, studentId)
          ..answer = answer
          ..status = HomeworkStatus.submitted
          ..score = null
          ..comment = ''
          ..reviewFiles = const []
          ..submittedAt = sentAt
          ..reviewedAt = null;
        if (files.isNotEmpty) result.files = _pendingFiles(files);
      },
      send: () async {
        final uploaded = await _uploadHomeworkFiles(
          homework.groupId,
          'answers',
          files,
        );
        try {
          await _homeworkWrite(
            () => client!.from('assignment_results').upsert({
              'organization_id': groupById(homework.groupId).organizationId,
              'assignment_id': _serverId(homeworkId),
              'enrollment_id': _serverId(
                studentById(studentId, homework.groupId).enrollmentId,
              ),
              'answer': answer,
              'status': 'submitted',
              'score': null,
              'reviewed_by': null,
              'reviewed_at': null,
              'comment': '',
              'submitted_at': sentAt.toUtc().toIso8601String(),
              if (uploaded.isNotEmpty)
                'files': [for (final file in uploaded) file.toJson()],
              if (clearReviewFiles) 'review_files': <Object>[],
            }, onConflict: 'assignment_id,enrollment_id'),
          );
        } catch (_) {
          _removeHomeworkFiles(uploaded);
          rethrow;
        }
        return uploaded;
      },
      reconcile: (uploaded) {
        if (uploaded.isNotEmpty) {
          resultFor(homeworkId, studentId).files = uploaded;
        }
      },
    );
  }

  /// Marks an answer from 0 to 100. The score decides the outcome:
  /// [homeworkPassScore] or more accepts it, anything less returns it.
  Future<void> reviewHomework({
    required String homeworkId,
    required String studentId,
    required int score,
    required String comment,
    List<PickedFile> files = const [],
    bool allowResubmit = true,
  }) async {
    if (score < 0 || score > 100)
      throw ArgumentError('Ball 0–100 oralig‘ida bo‘lishi kerak.');
    final homework = homeworks.firstWhere((h) => h.id == resolveId(homeworkId));
    // The old 1–5 rule would refuse the score, or store it unreadable.
    if (!homeworkReviewReady) throw homeworkReviewMigration;
    studentById(studentId, homework.groupId);
    resultFor(homeworkId, studentId);
    final actor = activeUser;
    final status = score >= homeworkPassScore
        ? HomeworkStatus.accepted
        : HomeworkStatus.returned;
    final reviewedAt = DateTime.now();
    await _mutate<List<HomeworkFile>>(
      apply: () {
        if (!homeworks.any((h) => h.id == resolveId(homeworkId)))
          throw StateError('Vazifa saqlanmadi.');
        final result = resultFor(homeworkId, studentId)
          ..status = status
          ..score = score
          ..comment = comment
          ..reviewedAt = reviewedAt
          ..resubmitAllowed = allowResubmit;
        if (files.isNotEmpty) result.reviewFiles = _pendingFiles(files);
      },
      send: () async {
        final uploaded = await _uploadHomeworkFiles(
          homework.groupId,
          'reviews',
          files,
        );
        try {
          await _homeworkWrite(
            () => client!
                .from('assignment_results')
                .update({
                  'status': status.name,
                  'score': score,
                  'comment': comment,
                  'reviewed_by': int.parse(actor.membershipId),
                  'reviewed_at': reviewedAt.toUtc().toIso8601String(),
                  // Only once the column exists; before that a review still
                  // saves, and a returned answer stays open as before.
                  if (groupPlanReady) 'resubmit_allowed': allowResubmit,
                  if (uploaded.isNotEmpty)
                    'review_files': [
                      for (final file in uploaded) file.toJson(),
                    ],
                })
                .eq('assignment_id', _serverId(homeworkId))
                .eq(
                  'enrollment_id',
                  _serverId(
                    studentById(studentId, homework.groupId).enrollmentId,
                  ),
                )
                .select('id')
                .single(),
          );
        } catch (_) {
          _removeHomeworkFiles(uploaded);
          rethrow;
        }
        return uploaded;
      },
      reconcile: (uploaded) {
        if (uploaded.isNotEmpty) {
          resultFor(homeworkId, studentId).reviewFiles = uploaded;
        }
      },
    );
  }

  Future<void> addGroup({
    required String name,
    required String course,
    AppUser? teacher,
    required String schedule,
    required String room,
    List<int> weekDays = const [],
    String status = 'active',
    String lessonStartTime = '',
    String lessonEndTime = '',
    int? totalLessons,
    DateTime? startsOn,
  }) async {
    if (activeRole != AppRole.admin) throw StateError('Admin huquqi kerak.');
    final temp = _newId();
    final group = StudyGroup(
      id: temp,
      name: name,
      course: course,
      teacherId: teacher?.id ?? '',
      teacherMembershipId: teacher?.membershipId ?? '',
      teacherName: teacher?.name ?? 'Ustoz biriktirilmagan',
      schedule: schedule,
      room: room,
      organizationId: activeUser.organizationId,
      weekDays: List.unmodifiable(weekDays),
      status: status,
      lessonStartTime: lessonStartTime,
      lessonEndTime: lessonEndTime,
      totalLessons: totalLessons,
      startsOn: startsOn,
    );
    await _mutate<Map<String, dynamic>>(
      apply: () => groups.add(group),
      send: () =>
          client!.from('groups').insert(_groupValues(group)).select().single(),
      reconcile: (row) {
        groups[groups.indexWhere((g) => g.id == temp)] = group.copyWith(
          id: row['id'].toString(),
        );
        _ids[temp] = row['id'].toString();
      },
    );
  }

  Future<void> addLesson(
    String groupId,
    String topic,
    DateTime startsAt,
  ) async {
    final temp = _newId();
    await _mutate<Map<String, dynamic>>(
      apply: () {
        requireActiveGroup(groupId);
        final day = tashkentDate(startsAt).weekday;
        if (groupById(groupId).weekDays.isNotEmpty &&
            !groupById(groupId).weekDays.contains(day))
          throw StateError('Guruhning dars kunini tanlang.');
        lessons.add(
          Lesson(
            id: temp,
            groupId: groupById(groupId).id,
            topic: topic,
            startsAt: startsAt,
          ),
        );
      },
      send: () => client!
          .from('lessons')
          .insert({
            'organization_id': groupById(groupId).organizationId,
            'group_id': _serverId(groupId),
            'topic': topic,
            'starts_at': startsAt.toUtc().toIso8601String(),
          })
          .select()
          .single(),
      reconcile: (row) {
        lessons[lessons.indexWhere((l) => l.id == temp)] = Lesson(
          id: row['id'].toString(),
          groupId: row['group_id'].toString(),
          topic: row['topic'].toString(),
          startsAt: DateTime.parse(row['starts_at'].toString()).toLocal(),
          status: row['status'] as String? ?? 'planned',
        );
        _ids[temp] = row['id'].toString();
      },
    );
  }

  Future<void> setRole(String userId, AppRole role) =>
      saveProfile(users.firstWhere((u) => u.id == userId), {}, role: role);

  Future<void> assignStudent(String userId, String groupId) async {
    final user = users.firstWhere((u) => u.id == userId);
    final temp = _newId();
    await _mutate<Map<String, dynamic>>(
      apply: () {
        final group = groupById(groupId);
        final latest = users.firstWhere((u) => u.id == userId);
        final existing = students
            .where((s) => s.id == userId && s.groupId == group.id)
            .firstOrNull;
        students.removeWhere(
          (s) => s.id == userId && (s.groupId.isEmpty || s.groupId == group.id),
        );
        students.add(
          Student(
            id: userId,
            name: latest.name,
            phone: latest.phone,
            membershipId: latest.membershipId,
            enrollmentId: existing?.enrollmentId ?? temp,
            groupId: group.id,
          ),
        );
      },
      send: () => client!
          .from('enrollments')
          .upsert({
            'organization_id': groupById(groupId).organizationId,
            'group_id': _serverId(groupId),
            'student_membership_id': int.parse(user.membershipId),
            'ends_on': null,
          }, onConflict: 'group_id,student_membership_id')
          .select()
          .single(),
      reconcile: (row) {
        final index = students.indexWhere(
          (s) => s.id == userId && s.groupId == resolveId(groupId),
        );
        final student = students[index];
        students[index] = Student(
          id: student.id,
          name: student.name,
          phone: student.phone,
          membershipId: student.membershipId,
          groupId: row['group_id'].toString(),
          enrollmentId: row['id'].toString(),
        );
        _ids[temp] = row['id'].toString();
      },
    );
  }

  void addStudent(String name, String phone, String groupId) {
    if (isOnline)
      throw UnsupportedError('O‘quvchi avval ro‘yxatdan o‘tishi kerak.');
    students.add(
      Student(
        id: 'student-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        phone: phone,
        groupId: groupId,
      ),
    );
    notifyListeners();
  }

  /// Creates a pupil's or a teacher's account and reloads so they appear in
  /// the lists. The sign-up runs on its own client: the admin stays signed in
  /// as themselves, and the server decides the role from the sign-up itself,
  /// not from this call.
  Future<void> createAccount({
    required String name,
    required String login,
    required String password,
    AppRole role = AppRole.student,
  }) async {
    if (activeRole != AppRole.admin) throw StateError('Admin huquqi kerak.');
    if (!isOnline)
      throw UnsupportedError('Akkaunt yaratish faqat serverda ishlaydi.');
    // The server only ever signs someone up as a pupil or a teacher.
    if (role == AppRole.admin)
      throw ArgumentError('Admin akkauntini bu yerdan ochib bo‘lmaydi.');
    if (name.trim().isEmpty) throw ArgumentError('Ism va familiyani kiriting.');
    final problem = AuthService.validateLogin(login);
    if (problem != null) throw ArgumentError(problem);
    // Preferred: the database makes the account, so no session for it is
    // ever created here and nothing is announced to the browser's other
    // clients. Only when that function is absent does the app fall back to
    // signing up, which does sign the new account in — and then the admin's
    // own session has to be put back by hand.
    final madeInDatabase = await _createAccountInDatabase(
      name: name.trim(),
      login: login,
      password: password,
      role: role,
    );
    if (madeInDatabase) {
      await load();
      notifyListeners();
      return;
    }
    if (AppConfig.useServerAccountCreation &&
        await _createAccountOnServer(
          name: name.trim(),
          login: login,
          password: password,
          role: role,
        )) {
      await load();
      notifyListeners();
      return;
    }
    final adminSession = client!.auth.currentSession;
    final signUp =
        (newAccountClient ??
                () => SupabaseClient(
                  AppConfig.supabaseUrl,
                  AppConfig.supabasePublishableKey,
                  // Implicit flow: a throwaway client has no storage to
                  // keep a PKCE verifier in, and none is needed to sign a
                  // pupil up with a login and password.
                  authOptions: const AuthClientOptions(
                    authFlowType: AuthFlowType.implicit,
                    autoRefreshToken: false,
                  ),
                ))
            .call();
    String? createdId;
    try {
      final response = await AuthService(signUp).register(
        login: login,
        password: password,
        name: name.trim(),
        role: role.name,
      );
      createdId = response.user?.id;
      // Only a sign-up that worked leaves a new session to undo; a refused
      // one leaves the admin's own session untouched.
      await _restoreSession(adminSession);
    } finally {
      // Fire and forget: tearing the throwaway client down involves realtime
      // and isolate shutdown, and the admin should not wait on it — nor
      // should an error from the sign-up be held back behind it.
      unawaited(signUp.dispose());
    }
    await load();
    notifyListeners();
    // The server decides the role from the sign-up. A database whose
    // registration trigger predates that writes 'student' whatever was asked
    // for, and the new teacher turns up among the pupils with nothing to
    // explain it.
    final created = createdId == null
        ? null
        : users.where((u) => u.id == createdId).firstOrNull;
    if (created != null && created.role != role) {
      throw StateError(
        'Akkaunt ochildi, lekin server uni '
        '${created.role == AppRole.teacher ? 'ustoz' : 'o‘quvchi'} sifatida '
        'yaratdi. Bazadagi ro‘yxatdan o‘tish triggeri tanlangan rolni '
        'hisobga olmayapti: 20260918100000_registration_role.sql ni ishga '
        'tushiring.',
      );
    }
  }

  /// Creates the account in the database. False when that function is not
  /// there yet, leaving the caller to fall back to signing up.
  Future<bool> _createAccountInDatabase({
    required String name,
    required String login,
    required String password,
    required AppRole role,
  }) async {
    try {
      await client!.rpc(
        'create_account',
        params: {
          'p_login': AuthService.normalizeLogin(login),
          'p_password': password,
          'p_name': name,
          'p_role': role.name,
        },
      );
      return true;
    } on PostgrestException catch (error) {
      // PGRST202: not there yet — fall back.
      if (error.code == 'PGRST202') return false;
      // Anything else is the database's own verdict, and the admin should
      // read it rather than have the app try a second way.
      throw ArgumentError(error.message);
    }
  }

  /// Asks the edge function to create the account. False when it is not
  /// deployed, leaving the caller to fall back.
  Future<bool> _createAccountOnServer({
    required String name,
    required String login,
    required String password,
    required AppRole role,
  }) async {
    try {
      await client!.functions.invoke(
        'create-account',
        body: {
          'name': name,
          'login': login,
          'password': password,
          'role': role.name,
        },
      );
      return true;
    } on FunctionException catch (error) {
      // Not deployed: fall back to signing up on a throwaway client.
      if (error.status == 404) return false;
      // Anything else is the function's own verdict, and the admin should
      // read it rather than have the app try again a different way.
      final details = error.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'Akkaunt yaratilmadi.';
      throw ArgumentError(message);
    } catch (_) {
      // The function could not be reached at all; fall back as well.
      return false;
    }
  }

  /// Puts the admin's own session back after a sign-up replaced it.
  Future<void> _restoreSession(Session? saved) async {
    final token = saved?.refreshToken;
    if (saved == null || token == null) return;
    Future<void> restore() async {
      if (client!.auth.currentUser?.id == saved.user.id) return;
      try {
        await client!.auth.setSession(token);
      } catch (_) {
        // Nothing better to do here: the admin is asked to sign in again.
      }
    }

    await restore();
    // The browser-wide announcement can land after the first attempt, so
    // check again shortly — without holding up the caller, whose own result
    // (or error) should reach the admin straight away.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 250)).then((_) {
        if (!_disposed) restore();
      }),
    );
  }

  /// A pupil's account, for callers that open no other kind.
  Future<void> createStudentAccount({
    required String name,
    required String login,
    required String password,
  }) => createAccount(name: name, login: login, password: password);

  /// Removes a pupil or a teacher from the centre. The server decides who is
  /// allowed and hands the removed teacher's signatures to the acting admin,
  /// so a group's own record survives the removal.
  Future<void> deleteMember(String userId) async {
    if (activeRole != AppRole.admin) throw StateError('Admin huquqi kerak.');
    if (!isOnline) throw UnsupportedError('O‘chirish faqat serverda ishlaydi.');
    final user = users.firstWhere((u) => u.id == userId);
    if (user.id == activeUser.id)
      throw StateError('O‘zingizni o‘chira olmaysiz.');
    try {
      await client!.rpc(
        'delete_member',
        params: {'p_membership_id': int.parse(user.membershipId)},
      );
    } on PostgrestException catch (error) {
      // PGRST202: the function is not in the schema cache yet.
      if (error.code == 'PGRST202') throw memberRemovalMigration;
      rethrow;
    }
    await load();
    notifyListeners();
  }

  void addTeacher(String name) {
    if (isOnline)
      throw UnsupportedError('Ustoz avval ro‘yxatdan o‘tishi kerak.');
    users.add(
      AppUser(
        id: 'teacher-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        role: AppRole.teacher,
      ),
    );
    notifyListeners();
  }

  bool get profileFeaturesReady => !isOnline || _profileFeaturesReady;
  bool _profileFeaturesReady = false;

  /// False when the database predates the score_awards migration: rewards and
  /// penalties are then unavailable, but everything else keeps working.
  bool get scoreAwardsReady => !isOnline || _scoreAwardsReady;
  bool _scoreAwardsReady = false;

  /// False once a load finds the database predates the homework review
  /// migration (0–100 scores, several files, deleting homework). Starts true:
  /// only a load can prove it missing.
  bool get homeworkReviewReady => !isOnline || _homeworkReviewReady;
  bool _homeworkReviewReady = true;

  /// False once a load finds the database predates the group-plan migration
  /// (lesson count, start date, resubmission). Starts true: only a load can
  /// prove it missing.
  bool get groupPlanReady => !isOnline || _groupPlanReady;
  bool _groupPlanReady = true;

  /// False once a load finds the database has no group_classmates function: a
  /// pupil then sees only themselves, and the app says why instead of quietly
  /// showing an empty group.
  bool get classmatesReady => !isOnline || _classmatesReady;
  bool _classmatesReady = true;

  /// What the server counted for a classmate, whose attendance, homework and
  /// awards a pupil cannot read directly.
  final classmateResults =
      <String, ({int homework, int attendance, int reward, int penalty})>{};
  final branches = <String>[];
  final payments = <PaymentRecord>[];
  Map<String, dynamic> _studentRanks = {};
  final avatarUrls = <String, String>{};
  final avatarImages = <String, Uint8List>{};
  DashboardMetrics? _dashboardMetrics;
  DashboardMetrics get dashboardMetrics => DashboardMetrics(
    DashboardMetrics.fromUsers(users).current,
    activeRole == AppRole.admin ? _dashboardMetrics?.previous : null,
  );

  // Replace only the saved user and their derived labels. Keep list selections,
  // other records, and the previous-month baseline intact.
  void _applyProfile(
    String userId,
    Map<String, dynamic> values, {
    AppRole? role,
    String? outcome,
  }) {
    final index = users.indexWhere((user) => user.id == userId);
    final current = users[index];
    final isSelf = activeUser.id == userId;
    final updated = current.withProfile(values, role: role, outcome: outcome);
    users[index] = updated;
    if (isSelf) activeRole = updated.role;
    for (var i = 0; i < students.length; i++) {
      if (students[i].id == userId)
        students[i] = students[i].copyWith(
          name: updated.name,
          phone: updated.phone,
        );
    }
    if (updated.role == AppRole.student &&
        students.every((student) => student.id != userId)) {
      students.add(
        Student(
          id: updated.id,
          name: updated.name,
          phone: updated.phone,
          membershipId: updated.membershipId,
          groupId: '',
        ),
      );
    }
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].teacherId == userId)
        groups[i] = groups[i].copyWith(teacherName: updated.name);
    }
  }

  bool canEditProfile(AppUser user) =>
      activeRole == AppRole.admin ||
      (activeRole == AppRole.teacher && activeUser.id == user.id);
  bool canEditAvatar(AppUser user) =>
      activeRole == AppRole.admin || activeUser.id == user.id;
  bool canSetOutcome(AppUser user) =>
      user.role == AppRole.student &&
      (activeRole == AppRole.admin ||
          (activeRole == AppRole.teacher &&
              students.any(
                (student) =>
                    student.id == user.id &&
                    !student.completed &&
                    visibleGroups.any((group) => group.id == student.groupId),
              )));

  Future<void> saveProfile(
    AppUser user,
    Map<String, dynamic> fields, {
    String? outcome,
    AppRole? role,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) async {
    if (fields.isNotEmpty && !canEditProfile(user))
      throw StateError('Bu profilni tahrirlashga ruxsat yo‘q.');
    if ((avatarBytes != null || removeAvatar) && !canEditAvatar(user))
      throw StateError('Rasmni o‘zgartirishga ruxsat yo‘q.');
    if (fields['branch'] is String &&
        (fields['branch'] as String).isNotEmpty &&
        !branches.contains(fields['branch']))
      throw ArgumentError('Ro‘yxatdan filial tanlang.');
    if (outcome != null && !canSetOutcome(user))
      throw StateError('Bitirganlik holatini o‘zgartirishga ruxsat yo‘q.');
    if (role != null && role != user.role && activeRole != AppRole.admin)
      throw StateError('Admin huquqi kerak.');
    final values = Map<String, dynamic>.of(fields);
    for (final field in ['first_name', 'last_name']) {
      if (values[field] is String)
        values[field] = (values[field] as String).trim();
    }
    final uploaded = avatarBytes == null
        ? null
        : '${user.id}/${DateTime.now().microsecondsSinceEpoch}.png';
    if (uploaded != null) {
      values['avatar_path'] = uploaded;
    } else if (removeAvatar) {
      values['avatar_path'] = null;
    }
    await _mutate<void>(
      apply: () {
        final old = users.firstWhere((u) => u.id == user.id).avatarPath;
        if (uploaded != null) avatarImages[uploaded] = avatarBytes!;
        _applyProfile(user.id, values, role: role, outcome: outcome);
        if ((uploaded != null || removeAvatar) && old != null) {
          avatarImages.remove(old);
          avatarUrls.remove(old);
        }
      },
      send: () async {
        String? old;
        if (uploaded != null || removeAvatar)
          old = _confirmedProfile(user.id).avatarPath;
        try {
          if (uploaded != null)
            await client!.storage
                .from('profile-avatars')
                .uploadBinary(
                  uploaded,
                  avatarBytes!,
                  fileOptions: const FileOptions(contentType: 'image/png'),
                );
          if (_disposed) throw MutationCancelled();
          await client!.rpc(
            'save_profile',
            params: {
              'p_membership_id': int.parse(user.membershipId),
              'p_profile': values,
              'p_outcome': outcome,
              'p_role': role?.name,
            },
          );
        } catch (_) {
          if (uploaded != null) unawaited(_removeAvatarFile(uploaded));
          rethrow;
        }
        if (old != null) unawaited(_removeAvatarFile(old));
      },
    );
  }

  Future<void> _removeAvatarFile(String path) async {
    try {
      await client!.storage.from('profile-avatars').remove([path]);
    } catch (_) {}
  }

  static AppRole _role(String value) =>
      AppRole.values.firstWhere((item) => item.name == value);
  static AttendanceStatus _attendance(String value) =>
      AttendanceStatus.values.firstWhere((item) => item.name == value);
  static HomeworkStatus _homework(String value) =>
      HomeworkStatus.values.firstWhere((item) => item.name == value);
  // Postgres `time` comes back as "HH:mm:ss"; keep just "HH:mm" client-side.
  static String _shortTime(String? value) =>
      value == null ? '' : value.substring(0, 5);
  static DateTime _today(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour);
  }

  static DateTime _day(int difference, int hour) {
    final date = DateTime.now().add(Duration(days: difference));
    return DateTime(date.year, date.month, date.day, hour);
  }
}

class _CrmSnapshot {
  _CrmSnapshot(CrmStore store)
    : payments = List.of(store.payments),
      branches = List.of(store.branches),
      users = List.of(store.users),
      groups = List.of(store.groups),
      students = List.of(store.students),
      lessons = List.of(store.lessons),
      homeworks = List.of(store.homeworks),
      role = store.activeRole,
      attendance = {
        for (final entry in store.attendance.entries)
          entry.key: Map.of(entry.value),
      },
      attendanceTimes = {
        for (final entry in store.attendanceTimes.entries)
          entry.key: Map.of(entry.value),
      },
      results = store.results
          .map(
            (r) => HomeworkResult(
              homeworkId: r.homeworkId,
              studentId: r.studentId,
              answer: r.answer,
              status: r.status,
              score: r.score,
              comment: r.comment,
              files: r.files,
              reviewFiles: r.reviewFiles,
              submittedAt: r.submittedAt,
              reviewedAt: r.reviewedAt,
              resubmitAllowed: r.resubmitAllowed,
            ),
          )
          .toList(),
      checkins = List.of(store.checkins),
      scoreAwards = List.of(store.scoreAwards),
      checkinImages = Map.of(store.checkinImages),
      avatarUrls = Map.of(store.avatarUrls),
      avatarImages = Map.of(store.avatarImages);
  final List<PaymentRecord> payments;
  final List<String> branches;
  final List<AppUser> users;
  final List<StudyGroup> groups;
  final List<Student> students;
  final List<Lesson> lessons;
  final List<Homework> homeworks;
  final AppRole role;
  final Map<String, Map<String, AttendanceStatus>> attendance;
  final Map<String, Map<String, String>> attendanceTimes;
  final List<HomeworkResult> results;
  final List<LessonCheckin> checkins;
  final List<ScoreAward> scoreAwards;
  final Map<String, Uint8List> checkinImages;
  final Map<String, String> avatarUrls;
  final Map<String, Uint8List> avatarImages;
  void restore(CrmStore store) {
    store.checkins
      ..clear()
      ..addAll(checkins);
    store.scoreAwards
      ..clear()
      ..addAll(scoreAwards);
    store.checkinImages
      ..clear()
      ..addAll(checkinImages);
    store.payments
      ..clear()
      ..addAll(payments);
    store.branches
      ..clear()
      ..addAll(branches);
    store.users
      ..clear()
      ..addAll(users);
    store.groups
      ..clear()
      ..addAll(groups);
    store.students
      ..clear()
      ..addAll(students);
    store.lessons
      ..clear()
      ..addAll(lessons);
    store.homeworks
      ..clear()
      ..addAll(homeworks);
    store.activeRole = role;
    store.attendance
      ..clear()
      ..addAll({
        for (final entry in attendance.entries) entry.key: Map.of(entry.value),
      });
    store.attendanceTimes
      ..clear()
      ..addAll({
        for (final entry in attendanceTimes.entries)
          entry.key: Map.of(entry.value),
      });
    final current = {
      for (final r in store.results) (r.homeworkId, r.studentId): r,
    };
    store.results
      ..clear()
      ..addAll(
        results.map((saved) {
          final result =
              current[(saved.homeworkId, saved.studentId)] ??
              HomeworkResult(
                homeworkId: saved.homeworkId,
                studentId: saved.studentId,
              );
          return result
            ..answer = saved.answer
            ..status = saved.status
            ..score = saved.score
            ..comment = saved.comment
            ..files = saved.files
            ..reviewFiles = saved.reviewFiles
            ..submittedAt = saved.submittedAt
            ..reviewedAt = saved.reviewedAt
            ..resubmitAllowed = saved.resubmitAllowed;
        }),
      );
    store.avatarUrls
      ..clear()
      ..addAll(avatarUrls);
    store.avatarImages
      ..clear()
      ..addAll(avatarImages);
  }
}
