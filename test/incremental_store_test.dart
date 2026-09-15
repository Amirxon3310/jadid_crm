import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/fake_crm_backend.dart';

void main() {
  late FakeCrmBackend backend;
  late CrmStore store;
  setUp(() async {
    backend = FakeCrmBackend();
    await backend.signIn();
    store = CrmStore.online(backend.client, enableLiveUpdates: false);
    await store.load();
    backend.calls.clear();
  });
  tearDown(() async {
    store.dispose();
    await backend.client.dispose();
  });
  void expectNoReload() {
    expect(backend.calls.where((r) => r.method == 'GET'), isEmpty);
    expect(
      backend.calls.where((r) => r.url.path.endsWith('dashboard_metrics')),
      isEmpty,
    );
  }

  test(
    'create group, lesson and homework from server IDs without reloading lists',
    () async {
      final existing = store.groups.single;
      final teacher = store.teachers.single;
      await store.addGroup(
        name: 'New group',
        course: 'New course',
        teacher: teacher,
        schedule: 'Tue',
        room: '2',
      );
      final created = store.groups.last;
      expect(created.id, '100');
      expect(created.teacherName, teacher.name);
      expect(identical(store.groups.first, existing), isTrue);
      await store.addLesson(
        created.id,
        'New lesson',
        DateTime.utc(2026, 9, 20, 12),
      );
      expect(store.lessons.single.id, '101');
      expect(store.lessons.single.groupId, created.id);
      await store.addHomework(
        created.id,
        'New task',
        'Details',
        DateTime.utc(2026, 9, 21),
      );
      expect(store.homeworks.single.id, '102');
      expect(store.homeworks.single.groupId, created.id);
      expectNoReload();
      expect(backend.calls.length, 3);
      for (final request in backend.calls) {
        expect(request.headers['prefer'], contains('return=representation'));
        expect(request.url.queryParameters['select'], '*');
      }
    },
  );
  test(
    'profile applies before acknowledgement and updates all derived names',
    () async {
      backend.writeGate = Completer<void>();
      final before = store.teachers.single;
      final group = store.groups.single;
      final save = store.saveProfile(before, {
        'first_name': 'Updated',
        'last_name': 'Teacher',
        'phone': '333',
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.teachers.single.name, 'Updated Teacher');
      expect(identical(store.teachers.single, before), isFalse);
      backend.writeGate!.complete();
      await save;
      expect(store.teachers.single.name, 'Updated Teacher');
      expect(store.groups.single.teacherName, 'Updated Teacher');
      expect(store.groups.single.id, group.id);
      expectNoReload();
      expect(backend.calls.single.url.path, endsWith('/rpc/save_profile'));
    },
  );
  test(
    'student edits update each enrollment and metrics keep previous-month baseline',
    () async {
      final student = store.users.last;
      final previous = store.dashboardMetrics.previous;
      await store.saveProfile(student, {
        'first_name': 'New',
        'last_name': 'Student',
        'phone': '444',
      }, outcome: 'graduated');
      expect(store.students.single.name, 'New Student');
      expect(store.students.single.phone, '444');
      expect(store.students.single.enrollmentId, '20');
      expect(store.dashboardMetrics.value('graduates').current, 1);
      expect(store.dashboardMetrics.value('success_rate').current, 100);
      expect(store.dashboardMetrics.previous, same(previous));
      await store.setRole(student.id, AppRole.teacher);
      expect(store.dashboardMetrics.value('students').current, 0);
      expect(store.dashboardMetrics.value('employees').current, 3);
      expect(store.dashboardMetrics.value('employees').previous, 1);
      expect(store.studentsOf('10'), isEmpty);
      expectNoReload();
    },
  );
  test(
    'enrollment upsert preserves other groups and never duplicates a row',
    () async {
      await store.addGroup(
        name: 'Second',
        course: 'Course',
        teacher: store.teachers.single,
        schedule: '',
        room: '',
      );
      final second = store.groups.last.id;
      final first = store.students.single;
      await store.assignStudent('student', second);
      expect(store.students.length, 2);
      expect(store.students.first, same(first));
      final enrollment = store.students.last.enrollmentId;
      await store.assignStudent('student', second);
      expect(store.students.length, 2);
      expect(store.students.last.enrollmentId, enrollment);
      await store.saveProfile(store.users.last, {'phone': '555'});
      expect(store.students.map((s) => s.phone), everyElement('555'));
      expectNoReload();
    },
  );
  test(
    'rejected profile, role, enrollment and inserts preserve saved state',
    () async {
      backend.failWrites = true;
      final student = store.users.last;
      final teacher = store.teachers.single;
      final groups = List.of(store.groups);
      final students = List.of(store.students);
      final denied = throwsA(isA<PostgrestException>());
      await expectLater(
        store.saveProfile(student, {
          'first_name': 'Rejected',
        }, outcome: 'graduated'),
        denied,
      );
      await expectLater(store.setRole(student.id, AppRole.teacher), denied);
      await expectLater(store.assignStudent(student.id, '10'), denied);
      await expectLater(
        store.addGroup(
          name: 'Rejected',
          course: 'Course',
          teacher: teacher,
          schedule: '',
          room: '',
        ),
        denied,
      );
      await expectLater(
        store.addLesson('10', 'Rejected', DateTime.now()),
        denied,
      );
      await expectLater(
        store.addHomework('10', 'Rejected', '', DateTime.now()),
        denied,
      );
      expect(store.users.last, same(student));
      expect(store.groups, groups);
      expect(store.students, students);
      expect(store.lessons, isEmpty);
      expect(store.homeworks, isEmpty);
      expect(store.dashboardMetrics.value('graduates').current, 0);
      expectNoReload();
    },
  );
  test(
    'saved avatar uses uploaded bytes without downloading all avatars',
    () async {
      final bytes = Uint8List.fromList([137, 80, 78, 71]);
      await store.saveProfile(store.activeUser, {}, avatarBytes: bytes);
      final path = store.activeUser.avatarPath!;
      expect(store.avatarImages[path], bytes);
      expect(backend.calls.length, 2);
      expect(
        jsonDecode(backend.calls.last.body)['p_profile']['avatar_path'],
        path,
      );
      await store.saveProfile(store.activeUser, {}, removeAvatar: true);
      expect(store.activeUser.avatarPath, isNull);
      expect(store.avatarImages.containsKey(path), isFalse);
      await Future<void>.delayed(Duration.zero);
      expectNoReload();
    },
  );

  test('a database without the awards table still loads the rest', () async {
    final oldBackend = FakeCrmBackend()..missingTables.add('score_awards');
    await oldBackend.signIn();
    final oldStore = CrmStore.online(
      oldBackend.client,
      enableLiveUpdates: false,
    );
    addTearDown(() async {
      oldStore.dispose();
      await oldBackend.client.dispose();
    });

    // The missing table used to take the whole load down with it.
    await oldStore.load();
    expect(oldStore.groups, isNotEmpty);
    expect(oldStore.scoreAwards, isEmpty);
    expect(oldStore.scoreAwardsReady, isFalse);
    // Points still add up from lessons alone.
    expect(oldStore.pointsOf(oldStore.students.first.id), isA<int>());

    // Any other Postgrest failure is still a real failure.
    final brokenBackend = FakeCrmBackend()..missingTables.add('groups');
    await brokenBackend.signIn();
    final brokenStore = CrmStore.online(
      brokenBackend.client,
      enableLiveUpdates: false,
    );
    addTearDown(() async {
      brokenStore.dispose();
      await brokenBackend.client.dispose();
    });
    await expectLater(brokenStore.load(), throwsA(isA<PostgrestException>()));
  });
}
