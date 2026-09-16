import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_config.dart';
import 'package:jadid_crm/features/auth_page.dart';
import 'package:jadid_crm/features/registration_role_picker.dart';

void main() {
  testWidgets('the sign-in page offers no way to open an account', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.pumpAndSettle();

    expect(AppConfig.allowSelfRegistration, isFalse);
    expect(find.text('Akkaunt yo‘q — ro‘yxatdan o‘tish'), findsNothing);
    expect(find.byType(RegistrationRolePicker), findsNothing);
    // Only signing in.
    expect(find.widgetWithText(FilledButton, 'Kirish'), findsOneWidget);
  });

  testWidgets('the form itself is kept, ready to be turned back on', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthPage(allowRegistration: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akkaunt yo‘q — ro‘yxatdan o‘tish'));
    await tester.pumpAndSettle();

    expect(find.byType(RegistrationRolePicker), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Ro‘yxatdan o‘tish'),
      findsOneWidget,
    );
  });
}
