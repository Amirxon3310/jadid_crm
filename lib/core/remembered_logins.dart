import 'package:shared_preferences/shared_preferences.dart';

/// The logins that have signed in on this device, most recent first, so the
/// sign-in page can offer them instead of making someone type again.
///
/// Only the login is kept. A password would sit in plain text in the
/// browser's storage, readable by anyone who opens the same profile, and the
/// browser's own password manager already does that job properly.
abstract final class RememberedLogins {
  static const _key = 'remembered_logins';

  /// Enough for a shared computer at the centre without becoming a list.
  static const limit = 5;

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const [];
    } catch (_) {
      // No device storage — an unsupported platform, or a browser with site
      // data blocked. Signing in still works; it just offers nothing.
      return const [];
    }
  }

  /// Puts [login] at the front, keeping the list free of duplicates.
  static Future<void> remember(String login) async {
    final value = login.trim();
    if (value.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = <String>[...?prefs.getStringList(_key)]
        ..removeWhere((item) => item.toLowerCase() == value.toLowerCase());
      saved.insert(0, value);
      await prefs.setStringList(_key, saved.take(limit).toList());
    } catch (_) {
      // Remembering is a convenience; never let it fail a sign-in.
    }
  }

  static Future<void> forget(String login) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = <String>[...?prefs.getStringList(_key)]
        ..removeWhere(
          (item) => item.toLowerCase() == login.trim().toLowerCase(),
        );
      await prefs.setStringList(_key, saved);
    } catch (_) {
      // As above: nothing here is worth an error on screen.
    }
  }
}
