import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jadid_crm/data/auth_service.dart';
import 'package:jadid_crm/features/auth_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late AuthService service;
  late List<Map<String, dynamic>> payloads;

  setUp(() {
    payloads = [];
    client = SupabaseClient(
      'https://example.test',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryStorage(),
      ),
      httpClient: MockClient((request) async {
        payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'access_token': 'test-token',
            'refresh_token': 'refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'user-1',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service = AuthService(client);
  });
  tearDown(() async {
    await client.dispose();
  });

  test('login is normalized and has no deliverable email', () {
    expect(AuthService.addressFor(' Ali_123 '), 'ali_123@login.jadid.invalid');
    for (final value in [
      'ab',
      'ali@gmail.com',
      'ali name',
      'ali/name',
      'a' * 33,
    ]) {
      expect(AuthService.validateLogin(value), isNotNull);
    }
  });
  test('both registration roles and login use the same identity', () async {
    for (final role in ['student', 'teacher']) {
      final response = await service.register(
        login: ' Ali_123 ',
        password: 'test123',
        name: 'Ali Karimov',
        role: role,
      );
      expect(response.session, isNotNull);
      expect(payloads.last['email'], 'ali_123@login.jadid.invalid');
      expect(payloads.last['data']['registration_role'], role);
    }
    await service.signIn('ALI_123', 'test123');
    expect(payloads.last['email'], 'ali_123@login.jadid.invalid');
  });
  test('admin registration is rejected before making a request', () {
    expect(
      () => service.register(
        login: 'admin_test',
        password: 'test123',
        name: 'Admin',
        role: 'admin',
      ),
      throwsArgumentError,
    );
    expect(payloads, isEmpty);
  });
  test('existing email accounts can still sign in', () async {
    await service.signIn('old@example.com', 'test123');
    expect(payloads.last['email'], 'old@example.com');
  });
  testWidgets('registration lets user choose teacher without email input', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: AuthPage(authService: service)));
    await tester.tap(find.text('Akkaunt yo‘q — ro‘yxatdan o‘tish'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsNothing);
    expect(find.text('Login'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('role-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ustoz').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Ali');
    await tester.enterText(find.byType(TextField).at(1), 'ali_teacher');
    await tester.enterText(find.byType(TextField).at(2), 'test123');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Ro‘yxatdan o‘tish'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ro‘yxatdan o‘tish'));
    await tester.pumpAndSettle();
    expect(payloads.single['email'], 'ali_teacher@login.jadid.invalid');
    expect(payloads.single['data']['registration_role'], 'teacher');
    await tester.pumpWidget(const SizedBox());
  });
}

class _MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}
