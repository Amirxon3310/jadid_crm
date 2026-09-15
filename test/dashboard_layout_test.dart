import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/workspace.dart';

void main() {
  testWidgets('dashboard adapts to desktop and phone with asset navigation', (
    tester,
  ) async {
    final font = FontLoader('SF Pro Display');
    font.addFont(rootBundle.load('assets/fonts/SF-Pro-Display-Regular.otf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final store = CrmStore()..changeRole(AppRole.admin);
    final key = GlobalKey();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1536, 1092);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: buildTheme(),
          home: Workspace(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Top ustozlar'), findsOneWidget);
    await tester.runAsync(() async {
      for (final name in ['dashboards', 'groups', 'teachers', 'students']) {
        for (final status in ['active', 'noactive']) {
          await precacheImage(
            AssetImage('assets/icons/${name}_$status.png'),
            key.currentContext!,
          );
        }
      }
    });
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage());
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    await tester.runAsync(
      () => File(
        '/tmp/jadid-dashboard-desktop.png',
      ).writeAsBytes(bytes!.buffer.asUint8List()),
    );
    image!.dispose();
    Future<void> capture(String path) async {
      final snapshot = await tester.runAsync(() => boundary.toImage());
      final encoded = await tester.runAsync(
        () => snapshot!.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(
        () => File(path).writeAsBytes(encoded!.buffer.asUint8List()),
      );
      snapshot!.dispose();
    }

    await tester.tap(find.byTooltip('Profil va sozlamalar'));
    await tester.pumpAndSettle();
    await capture('/tmp/jadid-account-menu.png');
    await tester.tap(find.text('Mening profilim'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture('/tmp/jadid-profile-desktop.png');
    await tester.tap(find.text('Guruhlar').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  test('dark theme and text use the configured design system', () {
    final theme = buildTheme(brightness: Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'SF Pro Display');
  });
}
