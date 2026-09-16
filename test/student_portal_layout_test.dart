import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/app_router.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/data/student_portal.dart';
import 'package:jadid_crm/features/profile_page.dart';
import 'package:jadid_crm/features/payments_page.dart';

void main() {
  testWidgets('student dashboard and navigation fit desktop and phone', (
    tester,
  ) async {
    final store = CrmStore()..changeRole(AppRole.student);
    addTearDown(store.dispose);
    final own = store.activeUser.id, group = store.visibleGroups.first;
    store.results.add(
      HomeworkResult(
        homeworkId: 'earned',
        studentId: own,
        status: HomeworkStatus.accepted,
        score: 5,
      ),
    );
    store.payments.add(
      PaymentRecord(
        id: 'own',
        studentId: own,
        amount: 120000,
        paidOn: DateTime(2026, 9, 14),
        method: 'cash',
      ),
    );
    store.payments.add(
      PaymentRecord(
        id: 'peer',
        studentId: 'peer',
        amount: 999999,
        paidOn: DateTime(2026, 9, 14),
        method: 'cash',
      ),
    );
    store.lessons
      ..clear()
      ..addAll([
        Lesson(
          id: 'done',
          groupId: group.id,
          topic: 'Done',
          startsAt: DateTime(2026),
          status: 'completed',
        ),
        Lesson(
          id: 'next',
          groupId: group.id,
          topic: 'Next',
          startsAt: DateTime(2026),
        ),
      ]);
    for (final font in [
      ('SF Pro Display', 'assets/fonts/SF-Pro-Display-Regular.otf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1536, 1092);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp.router(
          theme: buildTheme(),
          routerConfig: buildRouter(store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in [
      'Jami ballar',
      'Guruhdagi o‘rningiz',
      'Markazdagi o‘rningiz',
      'Kursni tugatish',
      '50%',
    ])
      expect(find.text(text), findsOneWidget);
    expect(find.text('Jami xodimlar'), findsNothing);
    await tester.runAsync(() async {
      for (final asset in ['dashboards_active', 'groups_noactive', 'menu'])
        await precacheImage(
          AssetImage('assets/icons/$asset.png'),
          key.currentContext!,
        );
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/jadid-student-dashboard.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('To‘lovlar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentsPage), findsOneWidget);
    expect(find.text('120 000 so‘m'), findsNWidgets(2));
    expect(find.text('999 999 so‘m'), findsNothing);
    expect(find.text('To‘lov qo‘shish'), findsNothing);
    await tester.tap(find.byTooltip('Profil va sozlamalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mening profilim'));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    ))
      expect(field.enabled, isFalse);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Rasm yuklash'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('branch-')),
          )
          .onChanged,
      isNull,
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp.router(theme: buildTheme(), routerConfig: buildRouter(store)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Guruhlarim').hitTestable(), findsOneWidget);
    expect(find.text('To‘lovlar').hitTestable(), findsOneWidget);
    expect(find.text('Uy vazifalari').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Guruhlarim').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('admin records a payment from the phone form', (tester) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: store,
              builder: (context, _) => PaymentsPage(store: store),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('To‘lov qo‘shish'));
    await tester.pumpAndSettle();
    final amount = find.widgetWithText(TextFormField, 'Summa (so‘m)');
    await tester.enterText(amount, '450000');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.payments.single.amount, 450000);
    expect(find.text('450 000 so‘m'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('admin branch list populates profile dropdown', (tester) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    await store.addBranch('Chimboy');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfilePage(store: store, userId: store.activeUser.id),
          ),
        ),
      ),
    );
    final field = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('branch-')),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('branch-')));
    await tester.tap(find.byKey(const ValueKey('branch-')));
    await tester.pumpAndSettle();
    expect(find.text('Chimboy').hitTestable(), findsOneWidget);
    expect(field.onChanged, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
