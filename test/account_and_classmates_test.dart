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
          'homework_points': 12,
          'attendance_points': 30,
          'reward_points': 5,
          'penalty_points': -3,
        },
        {
          // The caller's own row: their figures must come from their own
          // rows, which stay live as they work, not from this.
          'profile_id': 'student',
          'membership_id': 3,
          'enrollment_id': 20,
          'full_name': 'Student Test',
          'avatar_path': null,
          'study_status': 'active',
          'points': 99,
          'homework_points': 99,
          'attendance_points': 99,
          'reward_points': 99,
          'penalty_points': -99,
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

    // A classmate's own rows are hidden, so the board's columns come from
    // the server rather than reading as zero.
    expect(store.homeworkPointsOf('peer-1'), 12);
    expect(store.attendancePointsOf('peer-1'), 30);
    expect(store.bonusPointsOf('peer-1'), 5);
    expect(store.penaltyPointsOf('peer-1'), -3);

    // The pupil's own figures still come from their own rows.
    expect(store.homeworkPointsOf('student'), isNot(99));
    expect(store.attendancePointsOf('student'), isNot(99));
  });

  test('a missing classmates function is noticed, not swallowed', () async {
    final backend = FakeCrmBackend()
      ..authId = 'student'
      ..missingFunctions.add('group_classmates');
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await store.load();

    // The rest of the app still loads; the group page uses this to say why
    // the pupil is alone in the list.
    expect(store.classmatesReady, isFalse);
    expect(store.groups, isNotEmpty);
  });

  test(
    'creating an account leaves the admin signed in as themselves',
    () async {
      final backend = FakeCrmBackend()..missingFunctions.add('create_account');
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

  testWidgets('a suggested login starts with a letter; the password does not', (
    tester,
  ) async {
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
    // The database checks a username's shape and refuses a leading
    // digit, so the login is a letter and three figures; the password
    // is free of that.
    expect(
      fields.first,
      matches(RegExp(r'^[a-z]\d{3}$')),
      reason: fields.first,
    );
    expect(fields.last, matches(RegExp(r'^\d{4}$')), reason: fields.last);
  });

  test('an admin replaces a password; nobody can read the old one', () async {
    final backend = FakeCrmBackend();
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await store.load();
    store.activeRole = AppRole.admin;

    await store.setAccountPassword('student', '4821');
    expect(backend.passwordResets, hasLength(1));
    expect(backend.passwordResets.single['p_profile_id'], 'student');
    expect(backend.passwordResets.single['p_password'], '4821');

    // Too short to be a password at all.
    await expectLater(
      store.setAccountPassword('student', '12'),
      throwsArgumentError,
    );
    // Only an admin may.
    store.activeRole = AppRole.teacher;
    await expectLater(
      store.setAccountPassword('student', '4821'),
      throwsStateError,
    );
  });

  test(
    'without the function, changing a password says which SQL to run',
    () async {
      final backend = FakeCrmBackend()
        ..missingFunctions.add('set_account_password');
      await backend.signIn();
      final store = CrmStore.online(backend.client, enableLiveUpdates: false);
      addTearDown(store.dispose);
      await store.load();
      store.activeRole = AppRole.admin;

      await expectLater(
        store.setAccountPassword('student', '4821'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('set_account_password'),
          ),
        ),
      );
    },
  );
}
