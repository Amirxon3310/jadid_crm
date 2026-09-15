import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/data/student_portal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/fake_crm_backend.dart';

void main() {
  test('points count accepted results once and equal totals share a rank', () {
    final store = CrmStore()..changeRole(AppRole.student);
    addTearDown(store.dispose);
    store.users.add(
      const AppUser(id: 'peer', name: 'Peer', role: AppRole.student),
    );
    store.attendance.clear();
    store.results
      ..clear()
      ..addAll([
        HomeworkResult(
          homeworkId: 'a',
          studentId: store.activeUser.id,
          status: HomeworkStatus.accepted,
          score: 100,
        ),
        HomeworkResult(
          homeworkId: 'b',
          studentId: store.activeUser.id,
          status: HomeworkStatus.returned,
          score: 80,
        ),
        HomeworkResult(
          homeworkId: 'a',
          studentId: 'peer',
          status: HomeworkStatus.accepted,
          score: 100,
        ),
      ]);
    expect(store.pointsOf(store.activeUser.id), 5);
    expect(store.rankFor(), 1);
    store.results.add(
      HomeworkResult(
        homeworkId: 'c',
        studentId: 'peer',
        status: HomeworkStatus.accepted,
        score: 60,
      ),
    );
    expect(store.rankFor(), 2);
    expect(store.pointsOf('peer'), 8);
  });
  test(
    'course progress uses completed lessons and excludes cancelled lessons',
    () async {
      final store = CrmStore()..changeRole(AppRole.admin);
      addTearDown(store.dispose);
      final group = store.groups.first;
      store.lessons
        ..clear()
        ..addAll([
          Lesson(
            id: '1',
            groupId: group.id,
            topic: 'One',
            startsAt: DateTime(2020),
            status: 'completed',
          ),
          Lesson(
            id: '2',
            groupId: group.id,
            topic: 'Two',
            startsAt: DateTime(2020),
          ),
          Lesson(
            id: '3',
            groupId: group.id,
            topic: 'Cancelled',
            startsAt: DateTime(2020),
            status: 'cancelled',
          ),
        ]);
      expect(store.progressFor(group.id).label, '50%');
      await store.setLessonStatus('2', 'completed');
      expect(store.progressFor(group.id).label, '100%');
      store.lessons.clear();
      expect(store.progressFor(group.id).label, '—');
    },
  );
  test(
    'student profile is read only while own avatar stays editable',
    () async {
      final store = CrmStore()..changeRole(AppRole.student);
      addTearDown(store.dispose);
      expect(store.canEditProfile(store.activeUser), isFalse);
      expect(store.canEditAvatar(store.activeUser), isTrue);
      await expectLater(
        store.saveProfile(store.activeUser, {'phone': 'Forbidden'}),
        throwsStateError,
      );
      await store.saveProfile(
        store.activeUser,
        {},
        avatarBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(store.activeUser.avatarPath, isNotNull);
      await expectLater(store.addBranch('Forbidden'), throwsStateError);
      await expectLater(
        store.addPayment(
          studentId: store.activeUser.id,
          amount: 100,
          paidOn: DateTime.now(),
          method: 'cash',
        ),
        throwsStateError,
      );
    },
  );
  test(
    'payments, branches and enrollment changes are optimistic and roll back independently',
    () async {
      final backend = FakeCrmBackend();
      await backend.signIn();
      final store = CrmStore.online(backend.client, enableLiveUpdates: false);
      addTearDown(store.dispose);
      addTearDown(backend.client.dispose);
      await store.load();
      backend.calls.clear();
      backend.writeGate = Completer<void>();
      backend.failWriteNumbers.add(1);
      final payment = store.addPayment(
        studentId: 'student',
        amount: 200000,
        paidOn: DateTime(2026, 9, 14),
        method: 'cash',
        groupId: '10',
      );
      final failure = expectLater(payment, throwsA(isA<PostgrestException>()));
      final branch = store.addBranch('New');
      final enrollment = store.setEnrollmentCompleted('student', '10', true);
      expect(store.payments.single.amount, 200000);
      expect(store.branches, ['New']);
      expect(store.studentById('student', '10').completed, isTrue);
      backend.writeGate!.complete();
      await Future.wait([failure, branch, enrollment]);
      expect(store.payments, isEmpty);
      expect(store.branches, ['New']);
      expect(store.studentById('student', '10').completed, isTrue);
      expect(backend.calls.where((r) => r.method == 'GET'), isEmpty);
      await store.addPayment(
        studentId: 'student',
        amount: 300000,
        paidOn: DateTime(2026, 9, 14),
        method: 'card',
      );
      expect(store.payments.single, isA<PaymentRecord>());
      expect(store.payments.single.id, isNot(startsWith('pending-')));
    },
  );
}
