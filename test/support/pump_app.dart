import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/app_router.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';

/// Pumps the real app at [location], so a test walks the same routes the
/// browser's address bar does.
Future<void> pumpApp(
  WidgetTester tester,
  CrmStore store, {
  String location = '/',
}) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: buildTheme(),
      routerConfig: buildRouter(store, initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
}
