import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/people_page.dart';

Future<void> _pump(WidgetTester tester, CrmStore store) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 2000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PeoplePage(store: store, showTeachers: false),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A store with three pupils: one in a group, one frozen, one unassigned.
CrmStore _store() {
  final store = CrmStore()..changeRole(AppRole.admin);
  store.users.addAll([
    const AppUser(
      id: 'student-2',
      name: 'Madina Salimova',
      role: AppRole.student,
    ),
    const AppUser(id: 'nobody', name: 'Guruhsiz Bola', role: AppRole.student),
  ]);
  store.students.add(
    const Student(id: 'nobody', name: 'Guruhsiz Bola', groupId: '', phone: ''),
  );
  return store;
}

void main() {
  testWidgets('pupils can be found by name', (tester) async {
    final store = _store();
    addTearDown(store.dispose);
    await _pump(tester, store);

    expect(find.text('Ali Karimov'), findsOneWidget);
    expect(find.text('Madina Salimova'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ism bo‘yicha qidirish'),
      'madina',
    );
    await tester.pumpAndSettle();

    expect(find.text('Madina Salimova'), findsOneWidget);
    expect(find.text('Ali Karimov'), findsNothing);
  });

  testWidgets('pupils without a group can be picked out', (tester) async {
    final store = _store();
    addTearDown(store.dispose);
    await _pump(tester, store);

    expect(find.text('Guruhsiz Bola'), findsOneWidget);
    expect(find.text('Ali Karimov'), findsOneWidget);

    await tester.tap(find.text('Barcha o‘quvchilar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guruhga biriktirilmagan').last);
    await tester.pumpAndSettle();

    expect(find.text('Guruhsiz Bola'), findsOneWidget);
    expect(find.text('Ali Karimov'), findsNothing);
  });

  testWidgets('a frozen pupil is found under "not active"', (tester) async {
    final store = _store();
    addTearDown(store.dispose);
    await store.setEnrollmentStatus('student-2', 'g1', 'frozen');
    await _pump(tester, store);

    await tester.tap(find.text('Barcha holatlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faol emas').last);
    await tester.pumpAndSettle();

    expect(find.text('Madina Salimova'), findsOneWidget);
    expect(find.text('Ali Karimov'), findsNothing);

    // And clearing brings everyone back.
    await tester.tap(find.text('Tozalash'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Karimov'), findsOneWidget);
  });
}
