import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class AppColors {
  static const primary = Color(0xFF279EFA);
  static const background = Color(0xFFF4F5FE);
  static const success = Color(0xFF2DCD94);
  static const warning = Color(0xFFF5A623);
  static const danger = Color(0xFFFF4D4C);
  static const border = Color(0xFFE6EAF0);
  static const muted = Color(0xFF737373);
  static const ink = Color(0xFF061425);

  /// A soft primary-tinted fill for icon badges, avatars and selected tabs.
  /// The flat light-blue works on a white surface but needs a translucent
  /// tint on a dark one, so this reads the active theme instead of being a
  /// single constant.
  static Color softBlue(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? primary.withValues(alpha: .18)
      : const Color(0xFFEAF6FF);
}

final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
const _themeModeKey = 'theme_mode';

/// Restores the device's last saved dark/light choice. Call once before
/// `runApp` so the first frame already renders in the remembered mode.
Future<void> loadSavedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_themeModeKey) == 'dark') {
    appThemeMode.value = ThemeMode.dark;
  }
}

/// Switches the theme and remembers the choice on this device (browser
/// localStorage on web, platform prefs elsewhere) so it survives a reload.
Future<void> setThemeMode(ThemeMode mode) async {
  appThemeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_themeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
}

ThemeData buildTheme({Brightness brightness = Brightness.light}) => ThemeData(
  useMaterial3: true,
  brightness: brightness,
  fontFamily: 'SF Pro Display',
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ).copyWith(
        primary: AppColors.primary,
        surface: brightness == Brightness.dark
            ? const Color(0xFF1D2635)
            : Colors.white,
      ),
  scaffoldBackgroundColor: brightness == Brightness.dark
      ? const Color(0xFF121A28)
      : AppColors.background,
  dividerColor: AppColors.border,
  appBarTheme: AppBarTheme(
    backgroundColor: brightness == Brightness.dark
        ? const Color(0xFF1D2635)
        : Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: brightness == Brightness.dark
        ? const Color(0xFF293344)
        : AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // The button's own blue fill is constant in both themes, so its label
      // should always read in white rather than following onPrimary, which
      // can shift with the seeded color scheme.
      foregroundColor: Colors.white,
      iconColor: Colors.white,
    ),
  ),
  // A tappable row's hover/splash highlight should hug its own rounded
  // corners instead of the default sharp rectangle bleeding past them.
  listTileTheme: ListTileThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = 24,
    this.radius = 20,
  });
  final Widget child;
  final double padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.text,
    this.icon = Icons.inbox_outlined,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    ),
  );
}
