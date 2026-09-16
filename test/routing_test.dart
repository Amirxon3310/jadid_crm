import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/group_page.dart';
import 'package:jadid_crm/features/homework_pages.dart';
import 'package:jadid_crm/features/people_page.dart';
import 'package:jadid_crm/features/profile_page.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('a link opens the screen it names', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);

    // A group, straight to one of its tabs.
    await pumpApp(tester, store, location: '/groups/g1/reyting');
    expect(find.byType(GroupPage), findsOneWidget);
    expect(tester.widget<GroupPage>(find.byType(GroupPage)).startTab, 4);

    // A person.
    await pumpApp(tester, store, location: '/profile/student-1');
    expect(
      tester.widget<ProfilePage>(find.byType(ProfilePage)).userId,
      'student-1',
    );

    // A list.
    await pumpApp(tester, store, location: '/students');
    expect(find.byType(PeoplePage), findsOneWidget);

    // Something that is not there.
    await pumpApp(tester, store, location: '/groups/does-not-exist');
    expect(find.textContaining('topilmadi'), findsOneWidget);
  });

  testWidgets('the sidebar and a pupil’s name move the address', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1500, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);

    await pumpApp(tester, store);
    await tester.tap(find.text('Guruhlar'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupPage), findsNothing);

    // Opening a group from the list puts it in the address bar.
    await tester.tap(find.text('Xadra Kids N34'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupPage), findsOneWidget);

    // A pupil's name anywhere opens their own page.
    await tester.tap(find.text('Ali Karimov').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProfilePage>(find.byType(ProfilePage)).userId,
      'student-1',
    );
  });

  testWidgets('a homework has its own address', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.teacher);
    addTearDown(store.dispose);
    store.homeworks
      ..clear()
      ..add(
        Homework(
          id: 'h1',
          groupId: 'g1',
          title: 'Rasmdagi vazifalarni bajaring',
          description: '',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      );

    await pumpApp(tester, store, location: '/homeworks/h1');
    expect(find.byType(HomeworkDetailPage), findsOneWidget);
    expect(find.text('Kutayotganlar'), findsOneWidget);
  });

  testWidgets('a group tab puts itself in the address', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);

    await pumpApp(tester, store, location: '/groups/g1');
    expect(tester.widget<GroupPage>(find.byType(GroupPage)).startTab, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Reyting'));
    await tester.pumpAndSettle();
    // Rebuilt from the address, not switched in place.
    expect(tester.widget<GroupPage>(find.byType(GroupPage)).startTab, 4);
  });
}
