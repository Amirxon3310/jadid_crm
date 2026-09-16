import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/app_config.dart';
import 'data/crm_store.dart';
import 'data/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';
import 'features/auth_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  await loadSavedThemeMode();
  runApp(const CrmApp());
}

class CrmApp extends StatelessWidget {
  const CrmApp({super.key});
  @override
  Widget build(BuildContext context) => const AuthGate();
}

/// Wraps whatever the gate is showing in the app itself. Once a store is
/// loaded the app is routed, so every screen has an address.
Widget _app(ThemeMode mode, {Widget? home, GoRouter? router}) => router != null
    ? MaterialApp.router(
        title: AppConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: mode,
        routerConfig: router,
      )
    : MaterialApp(
        title: AppConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: mode,
        home: home,
      );

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.client});
  final SupabaseClient? client;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  CrmStore? store;
  GoRouter? router;
  String? error;
  int syncVersion = 0;
  String? sessionUserId;
  bool loading = false;
  SupabaseClient get client => widget.client ?? Supabase.instance.client;
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    authSubscription = client.auth.onAuthStateChange.listen((event) => _sync());
    _sync();
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    router?.dispose();
    store?.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final userId = client.auth.currentSession?.user.id;
    // Token refresh and duplicate signed-in events keep the existing workspace.
    if (userId != null && userId == sessionUserId && (loading || store != null))
      return;
    final version = ++syncVersion;
    sessionUserId = userId;
    store?.dispose();
    router?.dispose();
    setState(() {
      store = null;
      router = null;
      error = null;
      loading = userId != null;
    });
    if (userId == null) return;
    final next = CrmStore.online(client);
    try {
      await next.load();
      if (!mounted || version != syncVersion) {
        next.dispose();
        return;
      }
      setState(() {
        store = next;
        router = buildRouter(next);
        loading = false;
      });
    } catch (exception) {
      next.dispose();
      if (mounted && version == syncVersion) {
        setState(() {
          error = exception.toString();
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, mode, _) => _app(
      mode,
      router: router,
      home: router == null ? _gate(context) : null,
    ),
  );

  Widget _gate(BuildContext context) {
    if (client.auth.currentSession == null)
      return AuthPage(authService: AuthService(client));
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Ma’lumotlarni yuklab bo‘lmadi.'),
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _sync,
                  child: const Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
