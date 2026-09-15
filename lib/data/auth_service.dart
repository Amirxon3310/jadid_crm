import 'package:supabase_flutter/supabase_flutter.dart';

/// Usernames are represented by a non-deliverable, deterministic Auth address.
/// The domain is part of the account identity and must not change after launch.
class AuthService {
  AuthService(this.client);

  final SupabaseClient client;
  static const loginDomain = 'login.jadid.invalid';

  static String normalizeLogin(String value) => value.trim().toLowerCase();

  static String? validateLogin(String value) {
    if (!RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(normalizeLogin(value))) {
      return 'Login 3–32 ta lotin harfi, raqam yoki _ belgisidan iborat bo‘lsin.';
    }
    return null;
  }

  static String addressFor(String login) {
    final error = validateLogin(login);
    if (error != null) throw ArgumentError(error);
    return '${normalizeLogin(login)}@$loginDomain';
  }

  Future<AuthResponse> register({
    required String login,
    required String password,
    required String name,
    required String role,
  }) {
    if (role != 'student' && role != 'teacher') {
      throw ArgumentError('Faqat ustoz yoki o‘quvchi roli tanlanadi.');
    }
    return client.auth.signUp(
      email: addressFor(login),
      password: password,
      data: {
        'full_name': name.trim(),
        'username': normalizeLogin(login),
        'registration_role': role,
      },
    );
  }

  Future<AuthResponse> signIn(String login, String password) {
    // Existing email accounts retain access; new accounts use usernames.
    final identifier = login.trim().contains('@')
        ? login.trim().toLowerCase()
        : addressFor(login);
    return client.auth.signInWithPassword(
      email: identifier,
      password: password,
    );
  }
}
