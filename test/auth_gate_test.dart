import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/features/auth_page.dart';
import 'package:jadid_crm/features/workspace.dart';
import 'package:jadid_crm/main.dart';
import 'support/fake_crm_backend.dart';

void main() {
  testWidgets(
    'token refresh keeps loaded store, current menu and workspace without extra reads',
    (tester) async {
      final backend = FakeCrmBackend();
      await tester.runAsync(backend.signIn);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: AuthGate(client: backend.client),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      final before = tester.widget<Workspace>(find.byType(Workspace)).store;
      final requests = backend.calls.length;
      await tester.tap(find.byTooltip('Profil va sozlamalar'));
      await tester.pumpAndSettle();
      expect(find.text('Yangilash'), findsNothing);
      await tester.tap(find.text('Mening profilim'));
      await tester.pumpAndSettle();

      // Reopening the same session must not reconstruct the store or fetch its tables.
      await tester.runAsync(() => backend.client.auth.refreshSession());
      await tester.pumpAndSettle();
      expect(
        tester.widget<Workspace>(find.byType(Workspace)).store,
        same(before),
      );
      expect(backend.calls.length, requests);
      expect(find.text('O‘zgarishlarni saqlash'), findsOneWidget);
      await tester.runAsync(backend.signIn);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Workspace>(find.byType(Workspace)).store,
        same(before),
      );
      expect(backend.calls.length, requests);
      await tester.runAsync(() => backend.client.auth.signOut());
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byType(Workspace), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(backend.client.dispose);
    },
  );
  testWidgets('duplicate auth events during initial load only read data once', (
    tester,
  ) async {
    final backend = FakeCrmBackend()..readGate = Completer<void>();
    await tester.runAsync(backend.signIn);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AuthGate(client: backend.client),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.runAsync(() => backend.client.auth.refreshSession());
    expect(
      backend.calls.where((r) => r.url.path.endsWith('/profiles')).length,
      1,
    );
    backend.readGate!.complete();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.byType(Workspace), findsOneWidget);
    expect(
      backend.calls.where((r) => r.url.path.endsWith('/profiles')).length,
      1,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(backend.client.dispose);
  });
}
