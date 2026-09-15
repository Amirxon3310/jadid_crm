import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/core/app_notice.dart';
import 'package:jadid_crm/data/auth_service.dart';
import 'package:jadid_crm/features/auth_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PendingAuth extends AuthService {
  _PendingAuth(super.client);
  final pending = Completer<AuthResponse>();
  int calls = 0;
  @override
  Future<AuthResponse> signIn(String login, String password) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets('login shows spinner, blocks repeats and displays error at top', (
    tester,
  ) async {
    final client = await tester.runAsync(
      () async => SupabaseClient(
        'https://example.test',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    final auth = _PendingAuth(client!);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AuthPage(authService: auth),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'wunderkind');
    await tester.enterText(find.byType(TextField).at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Kirish'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(auth.calls, 1);
    auth.pending.completeError(
      const AuthException('Invalid credentials', code: 'invalid_credentials'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Login yoki parol noto‘g‘ri.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Login yoki parol noto‘g‘ri.')).dy,
      lessThan(150),
    );
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();
    expect(find.text('Login yoki parol noto‘g‘ri.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(client.dispose);
  });

  testWidgets('new notice replaces old notice and auto dismisses', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppNotice(context, 'Message ${++count}'),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Message 1'), findsNothing);
    expect(find.text('Message 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Message 2'), findsNothing);
  });
}
