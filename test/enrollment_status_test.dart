import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/group_page.dart';
import 'package:jadid_crm/features/profile_page.dart';

void main() {
  test('a frozen pupil is paused, not gone', () async {
    final store = CrmStore();
    addTearDown(store.dispose);
    store.activeRole = AppRole.admin;
    final pupil = store.studentsOf('g1').first;

    await store.setEnrollmentStatus(pupil.id, 'g1', 'frozen');
    final frozen = store.studentById(pupil.id, 'g1');
    expect(frozen.status, 'frozen');
    expect(frozen.statusLabel, 'Muzlatgan');
    // Inactive, so the server's own rules (no attendance, no homework)
    // and the app agree.
    expect(frozen.active, isFalse);
    expect(frozen.completed, isFalse);
    expect(frozen.left, isFalse);

    await store.setEnrollmentStatus(pupil.id, 'g1', 'active');
    expect(store.studentById(pupil.id, 'g1').active, isTrue);
    await expectLater(
      store.setEnrollmentStatus(pupil.id, 'g1', 'paused'),
      throwsArgumentError,
    );
  });

  test('every state has its own colour', () {
    expect(enrollmentColor('active'), AppColors.success);
    expect(enrollmentColor('frozen'), AppColors.warning);
    expect(enrollmentColor('left'), AppColors.danger);
    expect(enrollmentColor('completed'), AppColors.primary);
    expect(enrollmentStatuses.map((o) => o.label), [
      'Faol',
      'Muzlatgan',
      'Bitirgan',
      'Ketgan',
    ]);
  });

  testWidgets('the group list shows the status but never edits it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore();
    addTearDown(store.dispose);
    store.activeRole = AppRole.admin;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StatusTag), findsWidgets);
    // Even an admin cannot change it from here: it belongs to the profile.
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('an admin changes the status from the pupil’s profile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore();
    addTearDown(store.dispose);
    store.activeRole = AppRole.admin;
    final pupil = store.studentsOf('g1').first;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfilePage(store: store, userId: pupil.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = find.byKey(const ValueKey('enrolment-g1-active'));
    expect(picker, findsOneWidget);
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muzlatgan').last);
    await tester.pumpAndSettle();

    expect(store.studentById(pupil.id, 'g1').status, 'frozen');
    // Let the saved notice run out.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a teacher only reads the status on a profile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore();
    addTearDown(store.dispose);
    store.activeRole = AppRole.teacher;
    final pupil = store.studentsOf('g1').first;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfilePage(store: store, userId: pupil.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('enrolment-g1-active')), findsNothing);
    expect(find.byType(StatusTag), findsOneWidget);
  });
}
