import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/core/navigation.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/group_page.dart';
import 'package:jadid_crm/features/student_dashboard_page.dart';

void main() {
  testWidgets('a pupil sees the group, its homework and the rating only', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.student);
    addTearDown(store.dispose);
    // The demo data lists one pupil account; the group needs a few for a
    // board — and a team — to mean anything.
    store.users.addAll([
      const AppUser(
        id: 'student-2',
        name: 'Madina Salimova',
        role: AppRole.student,
      ),
      const AppUser(
        id: 'student-3',
        name: 'Aziz Rustamov',
        role: AppRole.student,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ['Ma’lumot', 'Uy vazifalari', 'Reyting']) {
      expect(find.widgetWithText(TextButton, tab), findsOneWidget, reason: tab);
    }
    // The register and the journal are the staff's.
    expect(find.widgetWithText(TextButton, 'Davomat'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Jurnal'), findsNothing);

    // Everyone in the group is listed, but no name is a way into a profile.
    expect(find.text('Ali Karimov'), findsOneWidget);
    expect(find.byType(PersonName), findsNothing);

    // The team builder works for a pupil too.
    await tester.tap(find.widgetWithText(TextButton, 'Reyting'));
    await tester.pumpAndSettle();
    expect(find.text('Jamoa tuzish'), findsOneWidget);
    // Nothing on the board is editable by them.
    expect(find.text('Ball qo‘shish'), findsNothing);
  });

  test(
    'a returned answer comes back only when the teacher allowed it',
    () async {
      final store = CrmStore();
      addTearDown(store.dispose);
      final pupil = store.studentsOf('g1').first;
      final homework = store.homeworksOf('g1').first;

      store.resultFor(homework.id, pupil.id)
        ..status = HomeworkStatus.returned
        ..resubmitAllowed = false;
      await expectLater(
        store.submitHomework(homework.id, pupil.id, 'Qayta urinish'),
        throwsStateError,
      );

      store.resultFor(homework.id, pupil.id).resubmitAllowed = true;
      await store.submitHomework(homework.id, pupil.id, 'Qayta urinish');
      expect(
        store.resultFor(homework.id, pupil.id).status,
        HomeworkStatus.submitted,
      );
    },
  );

  test('a group carries its plan, and says when it ends', () {
    const group = StudyGroup(
      id: 'g',
      name: 'Start Junior',
      course: 'Dasturlash',
      teacherId: 't',
      teacherName: 'Ustoz',
      schedule: '',
      room: '',
      weekDays: [1, 3, 5],
      totalLessons: 24,
    );
    expect(group.scheduleKindLabel, 'Toq kunlari');
    expect(group.lessonsPerWeek, 3);
    // No start date yet, so no end date can be claimed.
    expect(group.endsOn, isNull);

    final planned = group.copyWith(startsOn: DateTime(2026, 9, 1));
    // 24 lessons, three a week: eight weeks from the first day.
    expect(planned.endsOn, DateTime(2026, 10, 26));

    // 25 lessons is eight weeks and one lesson over, and that lesson needs a
    // ninth week — a part week still counts.
    final ragged = planned.copyWith(totalLessons: 25);
    expect(ragged.endsOn!.difference(DateTime(2026, 9, 1)).inDays, 9 * 7 - 1);
    expect(
      group.copyWith(weekDays: const [2, 4, 6]).scheduleKindLabel,
      'Juft kunlari',
    );
    expect(
      group.copyWith(weekDays: const [3]).scheduleKindLabel,
      'Haftada bir kun',
    );
  });

  test('progress counts against the plan staff set', () {
    final store = CrmStore();
    addTearDown(store.dispose);
    store.groups[0] = store.groups.first.copyWith(totalLessons: 20);
    final id = store.groups.first.id;
    store.lessons
      ..clear()
      ..addAll([
        for (var i = 0; i < 4; i++)
          Lesson(
            id: 'l$i',
            groupId: id,
            topic: 'Dars $i',
            startsAt: DateTime.now(),
            status: i < 3 ? 'completed' : 'planned',
          ),
      ]);

    final progress = store.progressFor(id);
    expect(progress.completed, 3);
    expect(progress.total, 20, reason: 'the plan, not the lessons entered');
  });

  testWidgets('the dashboard no longer asks which group', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.student);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentDashboardPage(store: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Guruh va kurs'), findsNothing);
  });
}
