import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/data/optimistic_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/fake_crm_backend.dart';

void main() {
  late FakeCrmBackend backend;
  late CrmStore store;
  var disposed = false;
  setUp(() async {
    disposed = false;
    backend = FakeCrmBackend();
    await backend.signIn();
    store = CrmStore.online(backend.client, enableLiveUpdates: false);
    await store.load();
    backend.calls.clear();
    backend.writeGate = Completer<void>();
  });
  tearDown(() async {
    if (!disposed) store.dispose();
    await backend.client.dispose();
  });
  test(
    'failed older edit preserves a newer edit and unrelated graduation',
    () async {
      backend.failWriteNumbers.add(1);
      final first = store.saveProfile(store.teachers.single, {
        'first_name': 'Rejected',
      });
      final failure = expectLater(first, throwsA(isA<PostgrestException>()));
      final second = store.saveProfile(store.teachers.single, {'phone': '777'});
      final third = store.saveProfile(
        store.users.last,
        {},
        outcome: 'graduated',
      );
      expect(store.teachers.single.name, 'Rejected Test');
      expect(store.teachers.single.phone, '777');
      expect(store.dashboardMetrics.value('graduates').current, 1);
      backend.writeGate!.complete();
      await Future.wait([failure, second, third]);
      expect(store.teachers.single.name, 'Teacher Test');
      expect(store.teachers.single.phone, '777');
      expect(store.groups.single.teacherName, 'Teacher Test');
      expect(store.dashboardMetrics.value('graduates').current, 1);
      expect(backend.calls.where((r) => r.method == 'GET'), isEmpty);
    },
  );
  test(
    'new group, lesson, enrollment and homework work immediately and resolve server IDs',
    () async {
      final groupSave = store.addGroup(
        name: 'New',
        course: 'Course',
        teacher: store.teachers.single,
        schedule: '',
        room: '',
      );
      final groupId = store.groups.last.id;
      final lessonSave = store.addLesson(groupId, 'Lesson', DateTime.utc(2026));
      final lessonId = store.lessons.single.id;
      final enrollmentSave = store.assignStudent('student', groupId);
      final homeworkSave = store.addHomework(
        groupId,
        'Homework',
        '',
        DateTime.utc(2026),
      );
      final homeworkId = store.homeworks.single.id;
      final attendanceSave = store.saveAttendance(lessonId, {
        'student': AttendanceStatus.present,
      });
      final answerSave = store.submitHomework(homeworkId, 'student', 'Answer');
      expect(store.attendance[lessonId]?['student'], AttendanceStatus.present);
      expect(store.resultFor(homeworkId, 'student').answer, 'Answer');
      expect(store.studentsOf(groupId), hasLength(1));
      backend.writeGate!.complete();
      await Future.wait([
        groupSave,
        lessonSave,
        enrollmentSave,
        homeworkSave,
        attendanceSave,
        answerSave,
      ]);
      final group = store.groupById(groupId);
      expect(group.id, isNot(startsWith('pending-')));
      expect(store.lessonsOf(groupId).single.groupId, group.id);
      expect(
        store.studentsOf(groupId).single.enrollmentId,
        isNot(startsWith('pending-')),
      );
      expect(
        store.attendance[store.resolveId(lessonId)]?['student'],
        AttendanceStatus.present,
      );
      expect(store.resultFor(homeworkId, 'student').answer, 'Answer');
      expect(backend.calls.any((r) => r.body.contains('pending-')), isFalse);
    },
  );
  test(
    'failed new group removes dependent rows but keeps an independent profile edit',
    () async {
      backend.failWriteNumbers.add(1);
      final groupSave = store.addGroup(
        name: 'Rejected',
        course: 'Course',
        teacher: store.teachers.single,
        schedule: '',
        room: '',
      );
      final groupId = store.groups.last.id;
      final lessonSave = store.addLesson(
        groupId,
        'Dependent lesson',
        DateTime.now(),
      );
      final taskSave = store.addHomework(
        groupId,
        'Dependent task',
        '',
        DateTime.now(),
      );
      final profileSave = store.saveProfile(store.activeUser, {
        'first_name': 'Kept',
      });
      final checks = Future.wait([
        expectLater(groupSave, throwsA(isA<PostgrestException>())),
        expectLater(lessonSave, throwsStateError),
        expectLater(taskSave, throwsStateError),
        profileSave,
      ]);
      expect(store.groups, hasLength(2));
      expect(store.lessons, hasLength(1));
      expect(store.homeworks, hasLength(1));
      backend.writeGate!.complete();
      await checks;
      expect(store.groups, hasLength(1));
      expect(store.lessons, isEmpty);
      expect(store.homeworks, isEmpty);
      expect(store.activeUser.displayFirstName, 'Kept');
      expect(backend.calls, hasLength(2));
    },
  );
  test(
    'avatar preview and profile roll back together when profile RPC is rejected',
    () async {
      backend.failWriteNumbers.add(
        2,
      ); // Upload succeeds, saving its path is rejected.
      final before = store.activeUser;
      final bytes = Uint8List.fromList([137, 80, 78, 71]);
      final save = store.saveProfile(before, {
        'first_name': 'Rejected',
      }, avatarBytes: bytes);
      final failed = expectLater(save, throwsA(isA<PostgrestException>()));
      final path = store.activeUser.avatarPath;
      expect(store.avatarImages[path], bytes);
      backend.writeGate!.complete();
      await failed;
      expect(store.activeUser, same(before));
      expect(store.avatarImages[path], isNull);
      await Future<void>.delayed(Duration.zero);
      expect(backend.calls.any((r) => r.method == 'DELETE'), isTrue);
    },
  );
  test(
    'closing the session cancels queued writes before they can use another session',
    () async {
      final first = store.saveProfile(store.activeUser, {
        'first_name': 'First',
      });
      final second = store.saveProfile(store.activeUser, {'phone': '777'});
      final checks = Future.wait([
        expectLater(first, throwsA(isA<MutationCancelled>())),
        expectLater(second, throwsA(isA<MutationCancelled>())),
      ]);
      await Future<void>.delayed(Duration.zero);
      store.dispose();
      disposed = true;
      backend.writeGate!.complete();
      await checks;
      expect(backend.calls, hasLength(1));
    },
  );
}
