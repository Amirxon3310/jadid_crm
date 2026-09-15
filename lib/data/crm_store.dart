import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dashboard_metrics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'student_portal.dart';
import 'optimistic_queue.dart';
part 'student_portal_store.dart';
part 'teacher_store.dart';

/// UI faqat shu sodda qatlam bilan ishlaydi. Demo rejim testlar uchun qolgan,
/// real ilova esa [CrmStore.online] orqali Supabase'dan foydalanadi.
class CrmStore extends ChangeNotifier {
  CrmStore() : client = null, enableLiveUpdates = false;
  CrmStore.online(this.client, {this.enableLiveUpdates = true}) {
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
  final bool enableLiveUpdates;
  RealtimeChannel? _liveChannel;
  Timer? _liveTimer;
  bool _refreshing = false;
  int _editVersion = 0;
  bool get isOnline => client != null;
  AppRole activeRole = AppRole.teacher;
  final checkins = <LessonCheckin>[];
  final checkinImages = <String, Uint8List>{};
  final _coinTotals = <String, int>{};
  final _coinBaseline = <String, int>{};

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
        name: user.name,
        phone: user.phone,
        groupId: row['group_id'].toString(),
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
      ..addAll(
        assignmentRows.map(
          (row) => Homework(
            id: row['id'].toString(),
            groupId: row['group_id'].toString(),
            title: row['title'].toString(),
            description: row['description'].toString(),
            dueDate: DateTime.parse(row['due_at'].toString()).toLocal(),
            lessonId: row['lesson_id']?.toString(),
          ),
        ),
      );

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
        attendanceTimes.putIfAbsent(
          lessonId,
          () => {},
        )[student.id] = arrivedAt.substring(0, 5);
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
        ),
      );
    }
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
  }) async {
    final temp = _newId();
    final actor = activeUser;
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
          ),
        );
      },
      send: () => client!
          .from('assignments')
          .insert({
            'organization_id': groupById(groupId).organizationId,
            'group_id': _serverId(groupId),
            'title': title,
            'description': description,
            'due_at': dueDate.toUtc().toIso8601String(),
            'lesson_id': lessonId == null ? null : _serverId(lessonId),
            'created_by': int.parse(actor.membershipId),
          })
          .select()
          .single(),
      reconcile: (row) {
        homeworks[homeworks.indexWhere((h) => h.id == temp)] = Homework(
          id: row['id'].toString(),
          groupId: row['group_id'].toString(),
          title: row['title'].toString(),
          description: row['description'].toString(),
          dueDate: DateTime.parse(row['due_at'].toString()).toLocal(),
          lessonId: row['lesson_id']?.toString(),
        );
        _ids[temp] = row['id'].toString();
      },
    );
  }

  Future<void> submitHomework(
    String homeworkId,
    String studentId,
    String answer,
  ) async {
    final homework = homeworks.firstWhere((h) => h.id == resolveId(homeworkId));
    if (!studentById(studentId, homework.groupId).active ||
        !groupById(homework.groupId).active)
      throw StateError('Bu guruhdagi o‘qish tugagan.');
    if (resultFor(homeworkId, studentId).status == HomeworkStatus.accepted) {
      throw StateError('Qabul qilingan javobni o‘zgartirib bo‘lmaydi.');
    }
    await _mutate<void>(
      apply: () {
        if (!homeworks.any((h) => h.id == resolveId(homeworkId)))
          throw StateError('Vazifa saqlanmadi.');
        resultFor(homeworkId, studentId)
          ..answer = answer
          ..status = HomeworkStatus.submitted
          ..score = null
          ..comment = '';
      },
      send: () async {
        await client!.from('assignment_results').upsert({
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
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'assignment_id,enrollment_id');
      },
    );
  }

  Future<void> reviewHomework({
    required String homeworkId,
    required String studentId,
    required bool accepted,
    required int score,
    required String comment,
  }) async {
    if (score < 1 || score > 5)
      throw ArgumentError('Baho 1–5 oralig‘ida bo‘lishi kerak.');
    final homework = homeworks.firstWhere((h) => h.id == resolveId(homeworkId));
    studentById(studentId, homework.groupId);
    resultFor(homeworkId, studentId);
    final actor = activeUser;
    final status = accepted ? HomeworkStatus.accepted : HomeworkStatus.returned;
    await _mutate<void>(
      apply: () {
        if (!homeworks.any((h) => h.id == resolveId(homeworkId)))
          throw StateError('Vazifa saqlanmadi.');
        resultFor(homeworkId, studentId)
          ..status = status
          ..score = score
          ..comment = comment;
      },
      send: () async {
        await client!
            .from('assignment_results')
            .update({
              'status': status.name,
              'score': score,
              'comment': comment,
              'reviewed_by': int.parse(actor.membershipId),
              'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('assignment_id', _serverId(homeworkId))
            .eq(
              'enrollment_id',
              _serverId(studentById(studentId, homework.groupId).enrollmentId),
            )
            .select('id')
            .single();
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
            ),
          )
          .toList(),
      checkins = List.of(store.checkins),
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
  final Map<String, Uint8List> checkinImages;
  final Map<String, String> avatarUrls;
  final Map<String, Uint8List> avatarImages;
  void restore(CrmStore store) {
    store.checkins
      ..clear()
      ..addAll(checkins);
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
            ..comment = saved.comment;
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
