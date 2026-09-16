import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../core/app_notice.dart';
import '../core/app_icon.dart';
import 'registration_role_picker.dart';
import '../data/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.authService,
    this.allowRegistration = AppConfig.allowSelfRegistration,
  });

  final AuthService? authService;

  /// Whether the way into the sign-up form is offered. Off in the app while
  /// the centre opens every account itself; a test turns it on to exercise
  /// the form that stays behind it.
  final bool allowRegistration;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final name = TextEditingController();
  final login = TextEditingController();
  final password = TextEditingController();
  String registrationRole = 'student';
  bool register = false;
  bool loading = false;
  bool passwordVisible = false;

  @override
  void dispose() {
    name.dispose();
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading) return;
    final loginError = !register && login.text.contains('@')
        ? null
        : AuthService.validateLogin(login.text);
    if (loginError != null) {
      _message(loginError);
      return;
    }
    if (password.text.length < 6) {
      _message('Parol kamida 6 ta belgidan iborat bo‘lsin.');
      return;
    }
    if (register && name.text.trim().length < 2) {
      _message('Ismingizni kiriting.');
      return;
    }

    setState(() => loading = true);
    try {
      final auth = widget.authService ?? AuthService(Supabase.instance.client);
      if (register) {
        final response = await auth.register(
          login: login.text,
          password: password.text,
          name: name.text,
          role: registrationRole,
        );
        if (response.session == null) {
          _message(
            'Kirish yakunlanmadi. Markaz administratoriga murojaat qiling.',
          );
        }
      } else {
        await auth.signIn(login.text, password.text);
      }
    } on AuthException catch (error) {
      _message(switch (error.code) {
        'invalid_credentials' => 'Login yoki parol noto‘g‘ri.',
        'user_already_exists' ||
        'email_exists' => 'Bu login band. Boshqa login tanlang.',
        'email_not_confirmed' =>
          'Akkaunt hali faollashtirilmagan. Administratorga murojaat qiling.',
        _ => error.message,
      });
    } catch (_) {
      _message(
        'Ulanishda xatolik. Internetni tekshirib, qayta urinib ko‘ring.',
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    showAppNotice(context, text, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.school_outlined,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    AppConfig.appTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    register ? 'Yangi akkaunt ochish' : 'Tizimga kirish',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  if (register) ...[
                    TextField(
                      controller: name,
                      enabled: !loading,
                      decoration: const InputDecoration(labelText: 'Ism'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: login,
                    enabled: !loading,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Login',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: AppIcon('user', size: 20),
                      ),
                      helperText: register
                          ? 'Masalan: ali_karimov'
                          : 'Eski akkaunt uchun email ham kiritish mumkin',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    enabled: !loading,
                    obscureText: !passwordVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Parol',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: AppIcon('padlock', size: 20),
                      ),
                      suffixIcon: IconButton(
                        tooltip: passwordVisible
                            ? 'Parolni yashirish'
                            : 'Parolni ko‘rsatish',
                        onPressed: () =>
                            setState(() => passwordVisible = !passwordVisible),
                        icon: AppIcon(
                          passwordVisible ? 'eye_hide' : 'eye_view',
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  if (register) ...[
                    const SizedBox(height: 18),
                    RegistrationRolePicker(
                      value: registrationRole,
                      onChanged: loading
                          ? null
                          : (value) => setState(() => registrationRole = value),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Yuklanmoqda',
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Kuting...'),
                            ],
                          )
                        : Text(register ? 'Ro‘yxatdan o‘tish' : 'Kirish'),
                  ),
                  // The way into the sign-up form. Hidden while the centre
                  // opens every account itself; the form below it still
                  // works the moment this is turned back on.
                  if (widget.allowRegistration) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() {
                              register = !register;
                              passwordVisible = false;
                            }),
                      child: Text(
                        register
                            ? 'Akkauntim bor — kirish'
                            : 'Akkaunt yo‘q — ro‘yxatdan o‘tish',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
