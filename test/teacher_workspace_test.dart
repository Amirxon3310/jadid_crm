import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
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
    'attendance coins are unique per lesson and corrections reverse them',
    () async {
      final store = CrmStore()..changeRole(AppRole.admin);
      addTearDown(store.dispose);
      store.attendance.clear();
      store.results.clear();
      final lesson = store.lessons.first;
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.present,
      });
      expect(store.coinsOf('student-1'), 10);
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.late,
      });
      expect(store.coinsOf('student-1'), 10);
      store.results.add(
        HomeworkResult(
          homeworkId: 'h1',
          studentId: 'student-1',
          status: HomeworkStatus.accepted,
          score: 5,
        ),
      );
      expect(store.coinsOf('student-1'), 15);
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.absent,
      });
      expect(store.coinsOf('student-1'), 5);
      await store.saveAttendance(lesson.id, {
        'student-1': AttendanceStatus.present,
      });
      await store.setLessonStatus(lesson.id, 'cancelled');
      expect(store.coinsOf('student-1'), 5);
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
        expect(store.coinsOf('student'), 10);
        backend.writeGate!.complete();
        await Future.wait([check, attendanceCheck]);
        expect(store.coinsOf('student'), reject ? 0 : 10);
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
}
