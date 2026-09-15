import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/groups_page.dart';
import 'package:jadid_crm/features/workspace.dart';

/// Order the group tiles appear in, read from their headings.
List<String> _order(WidgetTester tester, List<String> names) {
  final rows = [
    for (final name in names) (name, tester.getTopLeft(find.text(name)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final row in rows) row.$1];
}

void main() {
  testWidgets('groups filter by teacher and sort by attendance', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 2600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore();
    addTearDown(store.dispose);
    store.activeRole = AppRole.admin;
    // The demo data lists only one pupil account; g2 needs one of its own.
    store.users.add(
      const AppUser(id: 'student-5', name: 'Zuhra', role: AppRole.student),
    );

    // g2 is the group keeping up; g1 has the same lesson and misses it.
    store.lessons
      ..clear()
      ..addAll([
        Lesson(
          id: 'l1',
          groupId: 'g1',
          topic: 'Dars',
          startsAt: DateTime.now(),
        ),
        Lesson(
          id: 'l2',
          groupId: 'g2',
          topic: 'Dars',
          startsAt: DateTime.now(),
        ),
      ]);
    for (final pupil in store.studentsOf('g1')) {
      store.attendance.putIfAbsent('l1', () => {})[pupil.id] =
          AttendanceStatus.absent;
    }
    for (final pupil in store.studentsOf('g2')) {
      store.attendance.putIfAbsent('l2', () => {})[pupil.id] =
          AttendanceStatus.present;
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: GroupsPage(store: store)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The old row of chips is gone; three labelled menus took its place.
    expect(find.byType(ChoiceChip), findsNothing);
    for (final label in ['Holat', 'Ustoz', 'Tartib']) {
      expect(find.text(label), findsOneWidget);
    }

    // Each tile carries the numbers the sorting is based on.
    expect(find.text('Davomat 0%'), findsOneWidget);
    expect(find.text('Davomat 100%'), findsOneWidget);

    // Alphabetical to begin with.
    expect(
      _order(tester, ['Scratch S03', 'Web dasturlash W02', 'Xadra Kids N34']),
      ['Scratch S03', 'Web dasturlash W02', 'Xadra Kids N34'],
    );

    await tester.tap(find.text('Nomi bo‘yicha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Davomat bo‘yicha').last);
    await tester.pumpAndSettle();

    // Best attendance on top; the group with no lessons to measure sits last.
    expect(
      _order(tester, ['Scratch S03', 'Web dasturlash W02', 'Xadra Kids N34']),
      ['Web dasturlash W02', 'Xadra Kids N34', 'Scratch S03'],
    );

    await tester.tap(find.text('Barcha ustozlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dilnoza Rahimova').last);
    await tester.pumpAndSettle();
    expect(find.text('Scratch S03'), findsOneWidget);
    expect(find.text('Xadra Kids N34'), findsNothing);
  });

  testWidgets('unmarked homework shows as a red badge on the menu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore();
    addTearDown(store.dispose);
    store.activeRole = AppRole.teacher;
    store.homeworks
      ..clear()
      ..add(
        Homework(
          id: 'h1',
          groupId: 'g1',
          title: 'Vazifa',
          description: '',
          dueDate: DateTime.now(),
        ),
      );
    store.results
      ..clear()
      ..addAll([
        for (final pupil in store.studentsOf('g1').take(2))
          HomeworkResult(
            homeworkId: 'h1',
            studentId: pupil.id,
            status: HomeworkStatus.submitted,
          ),
      ]);
    final waiting = store.unreviewedHomeworkCount();
    expect(waiting, greaterThan(0));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Workspace(store: store),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.text('$waiting');
    expect(badge, findsOneWidget);
    // Red, so it reads as something owed rather than as a count.
    expect(tester.widget<Text>(badge).style?.color, Colors.white);
    final painted = tester.widget<Container>(
      find.ancestor(of: badge, matching: find.byType(Container)).first,
    );
    expect((painted.decoration as BoxDecoration).color, AppColors.penaltyRed);
  });
}
