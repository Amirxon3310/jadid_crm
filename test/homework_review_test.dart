import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/core/migration.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/homework_pages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_crm_backend.dart';

/// A group on the fake server with one homework and one submitted answer.
Future<(FakeCrmBackend, CrmStore)> _online({
  void Function(FakeCrmBackend backend)? before,
}) async {
  final backend = FakeCrmBackend();
  backend.tables['assignments']!.add({
    'id': 40,
    'organization_id': 'org',
    'group_id': 10,
    'title': 'Rasmdagi vazifalarni bajaring',
    'description': '',
    'due_at': '2026-09-20T18:59:00Z',
    'created_at': '2026-09-13T12:00:00Z',
    'lesson_id': null,
    'files': <Object>[],
  });
  backend.tables['assignment_results']!.add({
    'id': 41,
    'organization_id': 'org',
    'assignment_id': 40,
    'enrollment_id': 20,
    'answer': 'uyga vazifa',
    'status': 'submitted',
    'score': null,
    'comment': '',
    'submitted_at': '2026-09-15T10:48:00Z',
    'files': [
      {'path': 'org/10/answers/1_0_a.png', 'name': 'a.png'},
    ],
    'review_files': <Object>[],
  });
  before?.call(backend);
  await backend.signIn();
  final store = CrmStore.online(backend.client, enableLiveUpdates: false);
  await store.load();
  return (backend, store);
}

int _writes(FakeCrmBackend backend) =>
    backend.calls.where((call) => call.method != 'GET').length;

void main() {
  test('the score decides: 60 and up accepts, below returns', () async {
    final (backend, store) = await _online();
    addTearDown(store.dispose);
    expect(store.homeworkReviewReady, isTrue);
    final answer = store.resultFor('40', 'student');
    expect(answer.submittedAt, isNotNull);
    expect(answer.files.single.name, 'a.png');

    await store.reviewHomework(
      homeworkId: '40',
      studentId: 'student',
      score: 60,
      comment: 'O‘tdi',
    );
    expect(store.resultFor('40', 'student').status, HomeworkStatus.accepted);
    final sent = jsonDecode(backend.calls.last.body) as Map;
    expect(sent['status'], 'accepted');
    expect(sent['score'], 60);

    await store.reviewHomework(
      homeworkId: '40',
      studentId: 'student',
      score: 59,
      comment: 'Qayta bajaring',
    );
    expect(store.resultFor('40', 'student').status, HomeworkStatus.returned);

    await expectLater(
      store.reviewHomework(
        homeworkId: '40',
        studentId: 'student',
        score: 101,
        comment: '',
      ),
      throwsArgumentError,
    );
  });

  test('a refusal stays a refusal, not a missing migration', () async {
    final (backend, store) = await _online();
    addTearDown(store.dispose);
    backend.failWrites = true;
    await expectLater(
      store.reviewHomework(
        homeworkId: '40',
        studentId: 'student',
        score: 80,
        comment: '',
      ),
      throwsA(isA<PostgrestException>()),
    );
    // Rolled back: still waiting to be marked.
    expect(store.resultFor('40', 'student').status, HomeworkStatus.submitted);
  });

  test(
    'a database without the migration is found at load, before any write',
    () async {
      final (backend, store) = await _online(
        before: (backend) =>
            backend.missingColumns['assignment_results'] = {'review_files'},
      );
      addTearDown(store.dispose);
      expect(store.homeworkReviewReady, isFalse);
      final before = _writes(backend);

      await expectLater(
        store.reviewHomework(
          homeworkId: '40',
          studentId: 'student',
          score: 80,
          comment: '',
        ),
        throwsA(isA<MigrationMissing>()),
      );
      await expectLater(
        store.deleteHomework('40'),
        throwsA(isA<MigrationMissing>()),
      );
      await expectLater(
        store.addHomework(
          '10',
          'Fayl bilan',
          '',
          DateTime.now().add(const Duration(days: 7)),
          files: [PickedFile('a.png', Uint8List(3))],
        ),
        throwsA(isA<MigrationMissing>()),
      );
      // Nothing reached the server, not even the files.
      expect(_writes(backend), before);

      // A homework without files needs nothing new and still saves.
      await store.addHomework(
        '10',
        'Faylsiz',
        '',
        DateTime.now().add(const Duration(days: 7)),
      );
      expect(store.homeworks.map((h) => h.title), contains('Faylsiz'));
    },
  );

  test('deleting a homework takes its answers with it', () async {
    final (backend, store) = await _online();
    addTearDown(store.dispose);
    await store.deleteHomework('40');
    expect(store.homeworks, isEmpty);
    expect(store.results.where((r) => r.homeworkId == '40'), isEmpty);
    expect(backend.tables['assignments'], isEmpty);
  });

  test('a delete the database refuses is put back', () async {
    final (_, store) = await _online(
      before: (backend) => backend.deleteBlocked.add('assignments'),
    );
    addTearDown(store.dispose);
    await expectLater(store.deleteHomework('40'), throwsStateError);
    expect(store.homeworks.single.id, '40');
  });

  test('a mark keeps a pupil’s total where the old scale had it', () {
    expect(homeworkPointsFor(100), 5);
    expect(homeworkPointsFor(80), 4);
    expect(homeworkPointsFor(60), 3);
    // Half rounds away from zero, as Postgres round(numeric) does in
    // coin_totals, so the app and the server agree.
    expect(homeworkPointsFor(50), 3);
    expect(homeworkPointsFor(49), 2);
    expect(homeworkPointsFor(0), 0);
    expect(homeworkPointsFor(null), 0);
  });

  testWidgets('a teacher opens a homework, sees who waits, and marks one', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore();
    addTearDown(store.dispose);
    store.activeRole = AppRole.teacher;
    final group = store.groups.first;
    final pupil = store.studentsOf(group.id).first;
    store.homeworks
      ..clear()
      ..add(
        Homework(
          id: 'h1',
          groupId: group.id,
          title: 'Rasmdagi vazifalarni bajaring',
          description: '',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      );
    store.results
      ..clear()
      ..add(
        HomeworkResult(
          homeworkId: 'h1',
          studentId: pupil.id,
          answer: 'uyga vazifa',
          status: HomeworkStatus.submitted,
          submittedAt: DateTime.now(),
        ),
      );
    Finder answerNote() => find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == 'uyga vazifa',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupHomeworkTab(store: store, group: group),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final heading in [
      'Mavzu',
      'Berilgan vaqt',
      'Tugash vaqti',
      'Dars sanasi',
    ]) {
      expect(find.text(heading), findsOneWidget);
    }
    expect(find.text('Uy vazifa qo‘shish'), findsOneWidget);

    await tester.tap(find.text('Rasmdagi vazifalarni bajaring'));
    await tester.pumpAndSettle();
    // The detail page lists who answered; the answer itself waits in the
    // panel.
    expect(find.text('Kutayotganlar'), findsOneWidget);
    expect(answerNote(), findsNothing);

    await tester.tap(find.text(pupil.name));
    await tester.pumpAndSettle();
    expect(find.text('O‘tish bali'), findsOneWidget);
    expect(answerNote(), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('review-score')), '45');
    await tester.pump();
    expect(find.text('Qaytariladi'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Yuborish'));
    await tester.pumpAndSettle();
    final result = store.resultFor('h1', pupil.id);
    expect(result.status, HomeworkStatus.returned);
    expect(result.score, 45);
    // Let the saved notice run out.
    await tester.pump(const Duration(seconds: 6));
  });
}
