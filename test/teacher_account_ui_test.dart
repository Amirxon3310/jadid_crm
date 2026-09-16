import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/people_page.dart';

Future<void> _pumpTeachers(WidgetTester tester, CrmStore store) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PeoplePage(store: store, showTeachers: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an admin can add a teacher', (tester) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    await _pumpTeachers(tester, store);
    expect(find.text('Ustoz qo‘shish'), findsOneWidget);
  });

  testWidgets('nobody else can', (tester) async {
    final store = CrmStore()..changeRole(AppRole.teacher);
    addTearDown(store.dispose);
    await _pumpTeachers(tester, store);
    expect(find.text('Ustoz qo‘shish'), findsNothing);
  });
}
