import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_icon.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/features/auth_page.dart';

void main() {
  testWidgets('login and registration can reveal and hide the same password', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const AuthPage(allowRegistration: true),
      ),
    );
    for (final registration in [false, true]) {
      if (registration) {
        await tester.tap(find.text('Akkaunt yo‘q — ro‘yxatdan o‘tish'));
        await tester.pumpAndSettle();
        expect(find.text('Ism'), findsOneWidget);
        expect(find.textContaining('familiya'), findsNothing);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('role-selector'))).dy,
          greaterThan(tester.getBottomLeft(find.byType(TextField).last).dy),
        );
      }
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'example123');
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.tap(find.byTooltip('Parolni ko‘rsatish'));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isFalse);
      expect(tester.widget<TextField>(field).controller!.text, 'example123');
      await tester.tap(find.byTooltip('Parolni yashirish'));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      expect(tester.widget<TextField>(field).controller!.text, 'example123');
      for (final asset in ['user', 'padlock', 'eye_view']) {
        expect(
          find.byWidgetPredicate((w) => w is AppIcon && w.name == asset),
          findsOneWidget,
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('animated registration roles stay visible on a phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final spec in [
      ('SF Pro Display', 'assets/fonts/SF-Pro-Display-Regular.otf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(spec.$1)..addFont(rootBundle.load(spec.$2))).load();
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: buildTheme(),
          home: const AuthPage(allowRegistration: true),
        ),
      ),
    );
    await tester.tap(find.text('Akkaunt yo‘q — ro‘yxatdan o‘tish'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-selector')));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('Ustoz').hitTestable(), findsOneWidget);
    await tester.runAsync(() async {
      for (final asset in [
        'user_noactive',
        'padlock',
        'eye_view',
        'students_active',
        'teachers_noactive',
      ]) {
        await precacheImage(
          AssetImage('assets/icons/$asset.png'),
          key.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/jadid-registration-phone.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.tap(find.text('Ustoz'));
    await tester.pumpAndSettle();
    expect(find.text('Ustoz'), findsOneWidget);
    expect(find.text('O‘quvchi'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
