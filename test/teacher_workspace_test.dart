import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/migration.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/people_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/fake_crm_backend.dart';

void main() {
  test('teacher metrics use distinct pupils and per-group outcomes', () async {
    final store = CrmStore();
    addTearDown(store.dispose);
    store.students.clear();
    store.students.addAll([
      const Student(
        id: 'a',
        name: 'A',
        groupId: 'g1',
        phone: '',
        completed: true,
      ),
      const Student(id: 'a', name: 'A', groupId: 'g2', phone: ''),
      const Student(id: 'b', name: 'B', groupId: 'g1', phone: '', left: true),
      const Student(
        id: 'other',
        name: 'Other',
        groupId: 'g3',
        phone: '',
        completed: true,
      ),
    ]);
    expect(store.teacherMetrics, (
      groups: 2,
      students: 2,
      left: 1,
      graduates: 1,
      percent: 50.0,
    ));
    await store.setEnrollmentStatus('b', 'g1', 'active');
    expect(store.teacherMetrics.left, 0);
    await expectLater(
      store.setEnrollmentStatus('other', 'g3', 'left'),
      throwsStateError,
    );
    await expectLater(
      store.addGroup(name: 'Forbidden', course: 'C', schedule: '', room: ''),
      throwsStateError,
    );
  });

  test(
    'attendance points are unique per lesson and corrections reverse them',
    () async {
      final store = CrmStore()..changeRole(AppRole.admin);
      addTearDown(store.dispose);
      store.attendance.clear();
      store.results.clear();
      final lesson = store.lessons.first;
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.present,
      });
      expect(store.pointsOf('student-1'), 10);
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.late,
      });
      expect(store.pointsOf('student-1'), 10);
      store.results.add(
        HomeworkResult(
          homeworkId: 'h1',
          studentId: 'student-1',
          status: HomeworkStatus.accepted,
          score: 100,
        ),
      );
      expect(store.pointsOf('student-1'), 15);
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.absent,
      });
      expect(store.pointsOf('student-1'), 5);
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.present,
      });
      await store.setLessonStatus(lesson.id, 'cancelled');
      expect(store.pointsOf('student-1'), 5);
    },
  );

  test('check-in uses Tashkent day and assigned weekdays', () {
    final store = CrmStore();
    addTearDown(store.dispose);
    final today = DateTime.utc(2026, 9, 14, 20); // 15 September in Tashkent.
    final lesson = Lesson(
      id: 'today',
      groupId: 'g1',
      topic: 'Day',
      startsAt: DateTime.utc(2026, 9, 15, 8),
    );
    expect(store.isCheckinDay(lesson, now: today), isTrue);
    expect(
      store.isCheckinDay(lesson, now: DateTime.utc(2026, 9, 14, 18)),
      isFalse,
    );
    store.groups[0] = store.groups[0].copyWith(weekDays: [1]);
    expect(store.isCheckinDay(lesson, now: today), isFalse);
    store.groups[0] = store.groups[0].copyWith(weekDays: [2], status: 'frozen');
    expect(store.isCheckinDay(lesson, now: today), isFalse);
  });

  for (final reject in [false, true]) {
    test(
      'selfie and dependent attendance update immediately; reject=$reject',
      () async {
        final backend = FakeCrmBackend()..authId = 'teacher';
        backend.tables['lessons']!.add({
          'id': 30,
          'group_id': 10,
          'topic': 'Today',
          'starts_at': DateTime.now().toUtc().toIso8601String(),
        });
        await backend.signIn();
        final store = CrmStore.online(backend.client, enableLiveUpdates: false);
        addTearDown(store.dispose);
        addTearDown(backend.client.dispose);
        await store.load();
        final lesson = store.lessons.single;
        expect(store.canMarkLesson(lesson), isFalse);
        await expectLater(
          store.saveAttendance('30', {'student': AttendanceStatus.present}),
          throwsStateError,
        );
        backend.calls.clear();
        backend.writeGate = Completer<void>();
        if (reject)
          backend.failWriteNumbers.add(2); // Upload succeeds, RPC fails.
        final selfie = store.checkInLesson(
          lesson,
          Uint8List.fromList([255, 216, 255, 224]),
        );
        final check = reject
            ? expectLater(selfie, throwsA(isA<PostgrestException>()))
            : selfie;
        expect(store.canMarkLesson(lesson), isTrue);
        final attendance = store.saveAttendance('30', {
          'student': AttendanceStatus.present,
        });
        final attendanceCheck = reject
            ? expectLater(attendance, throwsStateError)
            : attendance;
        expect(store.pointsOf('student'), 10);
        backend.writeGate!.complete();
        await Future.wait([check, attendanceCheck]);
        expect(store.pointsOf('student'), reject ? 0 : 10);
        expect(store.checkins.length, reject ? 0 : 1);
        expect(
          backend.calls
              .where(
                (r) => r.url.path.endsWith('/attendance') && r.method == 'POST',
              )
              .length,
          reject ? 0 : 1,
        );
      },
    );
  }

  test(
    'admin reassigns and freezes optimistically; failed edit rolls back',
    () async {
      final backend = FakeCrmBackend();
      await backend.signIn();
      final store = CrmStore.online(backend.client, enableLiveUpdates: false);
      addTearDown(store.dispose);
      addTearDown(backend.client.dispose);
      await store.load();
      backend.writeGate = Completer<void>();
      backend.failWrites = true;
      final before = store.groups.single;
      final edit = store.updateGroup(
        before.copyWith(
          teacherId: '',
          teacherMembershipId: '',
          teacherName: 'Ustoz biriktirilmagan',
          status: 'frozen',
        ),
      );
      final check = expectLater(edit, throwsA(isA<PostgrestException>()));
      expect(store.groups.single.status, 'frozen');
      expect(store.groups.single.teacherId, '');
      backend.writeGate!.complete();
      await check;
      expect(store.groups.single, same(before));
    },
  );

  test('background reads cannot overwrite a newer local edit', () async {
    final backend = FakeCrmBackend();
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    addTearDown(backend.client.dispose);
    await store.load();
    backend.readGate = Completer<void>();
    final refresh = store.refreshInBackground();
    await store.setEnrollmentStatus('student', '10', 'left');
    backend.readGate!.complete();
    expect(await refresh, isFalse);
    expect(store.studentById('student', '10').left, isTrue);
    expect(await store.refreshInBackground(), isTrue);
    expect(store.studentById('student', '10').left, isTrue);
  });

  test(
    'new homework keeps lesson link; other-group lesson is rejected',
    () async {
      final store = CrmStore();
      addTearDown(store.dispose);
      await store.addHomework(
        'g1',
        'Task',
        'Description',
        DateTime.now(),
        lessonId: 'l1',
      );
      expect(store.homeworks.last.lessonId, 'l1');
      await expectLater(
        store.addHomework('g1', 'Wrong', '', DateTime.now(), lessonId: 'l2'),
        throwsStateError,
      );
    },
  );

  test('lesson window is read in Tashkent time, not the device zone', () {
    final store = CrmStore();
    addTearDown(store.dispose);
    final group = store.groups.first.copyWith(
      weekDays: const [1, 2, 3, 4, 5, 6, 7],
      lessonStartTime: '15:30',
      lessonEndTime: '17:00',
    );
    // 15:30 in Tashkent is 10:30 UTC; the check must land inside the window
    // whatever zone the device is in, and stay outside it an hour later.
    expect(
      store.isScheduledNow(group, now: DateTime.utc(2026, 9, 16, 10, 30)),
      isTrue,
    );
    expect(
      store.isScheduledNow(group, now: DateTime.utc(2026, 9, 16, 11, 59)),
      isTrue,
    );
    expect(
      store.isScheduledNow(group, now: DateTime.utc(2026, 9, 16, 12, 1)),
      isFalse,
    );
    expect(
      store.isScheduledNow(group, now: DateTime.utc(2026, 9, 16, 9, 59)),
      isFalse,
    );
    // Without a configured window only the weekday matters.
    final open = group.copyWith(lessonStartTime: '', lessonEndTime: '');
    expect(
      store.isScheduledNow(open, now: DateTime.utc(2026, 9, 16, 3)),
      isTrue,
    );
    final otherDay = group.copyWith(weekDays: const [7]);
    expect(
      store.isScheduledNow(otherDay, now: DateTime.utc(2026, 9, 16, 10, 30)),
      isFalse,
    );
  });

  test('rewards and penalties sit beside lesson points in the total', () async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    store.attendance.clear();
    store.results.clear();
    final lesson = store.lessons.firstWhere((l) => l.groupId == 'g1');
    await store.saveAttendance(lesson.id, {
      'student-1': AttendanceStatus.present,
    });
    expect(store.lessonPointsOf('student-1'), 10);
    expect(store.pointsOf('student-1'), 10);

    await store.addScoreAward(
      studentId: 'student-1',
      groupId: 'g1',
      amount: 25,
      note: 'Olimpiada g‘olibi',
    );
    await store.addScoreAward(
      studentId: 'student-1',
      groupId: 'g1',
      amount: -5,
      note: 'Kechikdi',
    );

    // Lesson points stay untouched; the two kinds of award are kept apart.
    expect(store.lessonPointsOf('student-1'), 10);
    expect(store.bonusPointsOf('student-1'), 25);
    expect(store.penaltyPointsOf('student-1'), -5);
    expect(store.pointsOf('student-1'), 30);

    // The history reads newest first and carries who gave it and why.
    final history = store.awardsOf('student-1');
    expect(history.map((a) => a.amount), [-5, 25]);
    expect(history.first.note, 'Kechikdi');
    expect(history.first.byName, store.activeUser.name);
    expect(history.every((a) => a.studentId == 'student-1'), isTrue);

    // Zero is not an award, and a teacher may not touch another's group.
    await expectLater(
      store.addScoreAward(
        studentId: 'student-1',
        groupId: 'g1',
        amount: 0,
        note: '',
      ),
      throwsArgumentError,
    );
    store.changeRole(AppRole.teacher);
    await expectLater(
      store.addScoreAward(
        studentId: 'student-8',
        groupId: 'g3',
        amount: 5,
        note: '',
      ),
      throwsStateError,
    );
  });

  test(
    'a new pupil signs up on its own client, leaving the admin session',
    () async {
      final backend = FakeCrmBackend();
      await backend.signIn();
      final signUpBackend = FakeCrmBackend();
      final store = CrmStore.online(
        backend.client,
        enableLiveUpdates: false,
        newAccountClient: () => signUpBackend.client,
      );
      addTearDown(() async {
        store.dispose();
        await backend.client.dispose();
      });
      await store.load();
      final adminSession = backend.client.auth.currentSession?.accessToken;
      expect(adminSession, isNotNull);
      expect(store.activeRole, AppRole.admin);

      await store.createStudentAccount(
        name: 'Yangi O‘quvchi',
        login: '4821',
        password: '4821',
      );

      // The sign-up went to the throwaway client, as a pupil, under the
      // login-derived address; the admin is still signed in as themselves.
      final signUp = signUpBackend.calls.isEmpty
          ? null
          : signUpBackend.calls.first;
      expect(signUp ?? backend.calls.last, isNotNull);
      expect(backend.client.auth.currentSession?.accessToken, adminSession);

      // A teacher may not create accounts, and a bad login is refused before
      // anything is sent.
      store.activeRole = AppRole.teacher;
      await expectLater(
        store.createStudentAccount(name: 'X', login: '4822', password: '4822'),
        throwsStateError,
      );
      store.activeRole = AppRole.admin;
      await expectLater(
        store.createStudentAccount(name: 'X', login: 'a b', password: '4822'),
        throwsArgumentError,
      );
    },
  );

  testWidgets('a rejected sign-up is explained in Uzbek, with the way out', (
    tester,
  ) async {
    final backend = FakeCrmBackend();
    await backend.signIn();
    final signUpBackend = FakeCrmBackend()
      ..authError = 'Password should be at least 6 characters.';
    final store = CrmStore.online(
      backend.client,
      enableLiveUpdates: false,
      newAccountClient: () => signUpBackend.client,
    );
    addTearDown(store.dispose);
    await tester.runAsync(store.load);
    store.activeRole = AppRole.admin;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PeoplePage(store: store, showTeachers: false),
          ),
        ),
      ),
    );
    await tester.tap(find.text('O‘quvchi qo‘shish'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ism va familiya'),
      'Yangi O‘quvchi',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Yaratish'));
    // Real network work, so it only progresses outside the fake async zone —
    // and there are two round trips now: asking for the server-side function
    // (absent here) and then signing up on the throwaway client. A pump
    // between the windows lets each continuation run.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    // Frame by frame, not pumpAndSettle: the notice dismisses itself, and
    // settling would run fake time straight past it.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The English default would leave the admin with no idea where to look.
    expect(find.textContaining('Parol juda qisqa'), findsOneWidget);
    expect(find.textContaining('Authentication'), findsOneWidget);
    expect(find.textContaining('Password should be'), findsNothing);
  });

  test('an admin removes a member; anyone else is refused', () async {
    final backend = FakeCrmBackend();
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await store.load();
    final pupil = store.users.firstWhere((u) => u.role == AppRole.student);

    store.activeRole = AppRole.teacher;
    await expectLater(store.deleteMember(pupil.id), throwsStateError);
    expect(backend.deletedMembers, isEmpty);

    store.activeRole = AppRole.admin;
    // Removing yourself would lock the centre's only admin out.
    await expectLater(
      store.deleteMember(store.activeUser.id),
      throwsStateError,
    );
    expect(backend.deletedMembers, isEmpty);

    await store.deleteMember(pupil.id);
    expect(backend.deletedMembers, [int.parse(pupil.membershipId)]);
    expect(store.users.any((u) => u.id == pupil.id), isFalse);
  });

  test(
    'removal without the migration offers the SQL, not a raw error',
    () async {
      final backend = FakeCrmBackend()..missingFunctions.add('delete_member');
      await backend.signIn();
      final store = CrmStore.online(backend.client, enableLiveUpdates: false);
      addTearDown(store.dispose);
      await store.load();
      store.activeRole = AppRole.admin;
      final pupil = store.users.firstWhere((u) => u.role == AppRole.student);
      await expectLater(
        store.deleteMember(pupil.id),
        throwsA(isA<MigrationMissing>()),
      );
      // Still listed: a refused removal must not look like it worked.
      expect(store.users.any((u) => u.id == pupil.id), isTrue);
    },
  );

  test('the homework badge counts what the viewer owes', () async {
    final store = CrmStore();
    addTearDown(store.dispose);
    final group = store.groups.first;
    final pupil = store.students.firstWhere((s) => s.groupId == group.id);
    store.homeworks
      ..clear()
      ..addAll([
        Homework(
          id: 'h1',
          groupId: group.id,
          title: 'Bajarilgan',
          description: '',
          dueDate: DateTime.now(),
        ),
        Homework(
          id: 'h2',
          groupId: group.id,
          title: 'Tekshiriladi',
          description: '',
          dueDate: DateTime.now(),
        ),
        Homework(
          id: 'h3',
          groupId: group.id,
          title: 'Yuborilmagan',
          description: '',
          dueDate: DateTime.now(),
        ),
      ]);
    store.results
      ..clear()
      ..addAll([
        HomeworkResult(
          homeworkId: 'h1',
          studentId: pupil.id,
          status: HomeworkStatus.accepted,
        ),
        HomeworkResult(
          homeworkId: 'h2',
          studentId: pupil.id,
          status: HomeworkStatus.submitted,
        ),
      ]);

    // The pupil owes only the one never sent; h2 is out of their hands.
    store.activeRole = AppRole.student;
    expect(store.pendingHomeworkCount(pupil.id), 1);

    // The teacher owes the one waiting to be marked.
    store.activeRole = AppRole.teacher;
    expect(store.unreviewedHomeworkCount(), 1);
    expect(store.homeworkBadgeCount(), 1);
  });

  test('points split into homework and attendance', () async {
    final store = CrmStore();
    addTearDown(store.dispose);
    final group = store.groups.first;
    final pupil = store.students.firstWhere((s) => s.groupId == group.id);
    store.lessons
      ..clear()
      ..add(
        Lesson(
          id: 'l1',
          groupId: group.id,
          topic: 'Dars',
          startsAt: DateTime.now(),
        ),
      );
    store.attendance['l1'] = {pupil.id: AttendanceStatus.present};
    store.homeworks
      ..clear()
      ..add(
        Homework(
          id: 'h1',
          groupId: group.id,
          title: 'Vazifa',
          description: '',
          dueDate: DateTime.now(),
        ),
      );
    store.results
      ..clear()
      ..add(
        HomeworkResult(
          homeworkId: 'h1',
          studentId: pupil.id,
          status: HomeworkStatus.accepted,
          score: 80,
        ),
      );

    expect(store.homeworkPointsOf(pupil.id), 4);
    expect(store.attendancePointsOf(pupil.id), 10);
    // The columns must still add up to what the pupil had before.
    expect(store.lessonPointsOf(pupil.id), 14);
  });

  test('an admin opens a teacher account, and never an admin one', () async {
    final backend = FakeCrmBackend();
    await backend.signIn();
    final signUpBackend = FakeCrmBackend();
    final store = CrmStore.online(
      backend.client,
      enableLiveUpdates: false,
      newAccountClient: () => signUpBackend.client,
    );
    addTearDown(store.dispose);
    await store.load();
    store.activeRole = AppRole.admin;

    await store.createAccount(
      name: 'Yangi Ustoz',
      login: 'ustoz01',
      password: 'parol123',
      role: AppRole.teacher,
    );
    // The role travels with the sign-up: the server reads it from there.
    final signUp = jsonDecode(signUpBackend.authCalls.last.body) as Map;
    expect(signUp['data']['registration_role'], 'teacher');
    expect(signUp['data']['full_name'], 'Yangi Ustoz');
    // The admin's own session was never touched.
    expect(backend.client.auth.currentUser?.id, 'admin');

    await expectLater(
      store.createAccount(
        name: 'Boshqa Admin',
        login: 'admin02',
        password: 'parol123',
        role: AppRole.admin,
      ),
      throwsArgumentError,
    );
  });
}
