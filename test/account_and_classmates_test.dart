import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/people_page.dart';

import 'support/fake_crm_backend.dart';

void main() {
  test('a pupil is given their classmates and their points', () async {
    final backend = FakeCrmBackend()
      ..authId = 'student'
      ..classmates = [
        {
          'profile_id': 'peer-1',
          'membership_id': 9,
          'enrollment_id': 91,
          'full_name': 'Madina Salimova',
          'avatar_path': null,
          'study_status': 'active',
          'points': 42,
        },
        {
          'profile_id': 'peer-2',
          'membership_id': 10,
          'enrollment_id': 92,
          'full_name': 'Aziz Rustamov',
          'avatar_path': null,
          'study_status': 'frozen',
          'points': 17,
        },
      ];
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await store.load();

    // Row security hides other pupils' enrolments, so without this the board
    // would show the pupil alone.
    final names = store.studentsOf('10').map((s) => s.name);
    expect(names, containsAll(['Madina Salimova', 'Aziz Rustamov']));
    expect(store.pointsOf('peer-1'), 42);
    expect(store.pointsOf('peer-2'), 17);
    // Their state travels with them, so the board can mark it.
    expect(store.studentById('peer-2', '10').status, 'frozen');
    // Nothing else about them arrives: no phone, no email.
    expect(store.studentById('peer-1', '10').phone, isEmpty);
  });

  test(
    'creating an account leaves the admin signed in as themselves',
    () async {
      final backend = FakeCrmBackend();
      await backend.signIn();
      final signUpBackend = FakeCrmBackend()..authId = 'new-pupil';
      final store = CrmStore.online(
        backend.client,
        enableLiveUpdates: false,
        newAccountClient: () => signUpBackend.client,
      );
      addTearDown(store.dispose);
      await store.load();
      store.activeRole = AppRole.admin;

      final adminAuthCalls = backend.authCalls.length;
      await store.createAccount(
        name: 'Yangi O‘quvchi',
        login: 'pupil01',
        password: '482100',
      );

      // The sign-up happened on the throwaway client.
      expect(signUpBackend.authCalls, isNotEmpty);
      expect(store.activeUser.id, 'admin');
      // The restore itself is deliberately not asserted here. It only acts
      // when the admin's client has been switched to the new account, which
      // happens through a browser-wide announcement this fake cannot
      // reproduce: here the client keeps reporting the admin, so the restore
      // correctly does nothing and there is nothing to observe. Asserting the
      // signed-in id would pass whatever the code did.
      expect(adminAuthCalls, greaterThan(0));
    },
  );

  test('a login is read for an admin, and a failure stays quiet', () async {
    final backend = FakeCrmBackend();
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await store.load();

    expect(await store.memberLogin('student'), 'ali_karimov');

    // The page that shows it must survive the lookup failing outright.
    backend.rpcErrors['member_login'] = 403;
    expect(await store.memberLogin('student'), isNull);
  });

  testWidgets('a suggested login and password are six figures', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final backend = FakeCrmBackend();
    await tester.runAsync(backend.signIn);
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await tester.runAsync(store.load);
    store.activeRole = AppRole.admin;

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
    await tester.tap(find.text('O‘quvchi qo‘shish'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((field) => field.controller.text)
        .where((text) => text.isNotEmpty)
        .toList();
    expect(fields, hasLength(2), reason: 'the login and the password');
    for (final value in fields) {
      expect(value, matches(RegExp(r'^\d{6}$')), reason: value);
    }
  });
}
