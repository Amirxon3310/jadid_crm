import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/group_page.dart';

/// Reads the figure shown under a label in the team card.
String _stat(WidgetTester tester, String label) {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: row.first, matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  return texts.firstWhere((t) => t != label);
}

void main() {
  testWidgets('a team adds its members up and takes their place', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    store.users.addAll([
      const AppUser(id: 'student-2', name: 'Madina', role: AppRole.student),
      const AppUser(id: 'student-3', name: 'Aziz', role: AppRole.student),
    ]);
    String nameOf(String id) =>
        store.studentsOf('g1').firstWhere((s) => s.id == id).name;
    // Known points, nothing else in play: no lessons, no homework.
    store.lessons.clear();
    store.homeworks.clear();
    store.results.clear();
    store.attendance.clear();
    for (final (id, amount) in [
      ('student-1', 50),
      ('student-2', 30),
      ('student-3', 10),
    ]) {
      await store.addScoreAward(
        studentId: id,
        groupId: 'g1',
        amount: amount,
        note: 'boshlang‘ich',
      );
    }
    expect(store.pointsOf('student-1'), 50);
    expect(store.pointsOf('student-2'), 30);
    expect(store.pointsOf('student-3'), 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 4),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jamoa tuzish'));
    await tester.pumpAndSettle();
    // The card appears at once, asking for members.
    expect(find.textContaining('kamida ikki'), findsOneWidget);

    // Weakest and strongest together: 50 + 10 = 60, ahead of the other's 30.
    await tester.tap(find.text(nameOf('student-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(nameOf('student-3')));
    await tester.pumpAndSettle();
    expect(
      find.text('Jamoa bali'),
      findsOneWidget,
      reason: 'two pupils were picked, so the team should be counted',
    );

    expect(_stat(tester, 'Jamoa bali'), '60');
    expect(_stat(tester, 'A’zolar'), '2');
    expect(_stat(tester, 'O‘rin'), '1');

    // Dropping the strongest leaves 10, behind the other two.
    await tester.tap(find.text(nameOf('student-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('kamida bitta'), findsOneWidget);
  });
}
