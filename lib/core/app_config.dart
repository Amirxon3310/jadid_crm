abstract final class AppConfig {
  /// Whether anyone may open their own account from the sign-in page.
  ///
  /// Off for now: an admin enters pupils and teachers into the centre, and
  /// they only sign in. The sign-up screen itself is kept, so turning this
  /// back on restores it.
  static const allowSelfRegistration = false;

  static const centerName = 'Jadid';
  static const appTitle = '$centerName CRM';

  // Publishable key brauzerda ishlatilishi uchun mo'ljallangan.
  // Xohlasangiz build vaqtida --dart-define bilan almashtirishingiz mumkin.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://doquwqigqzhxrxgxyyxb.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_UYjYK_N-sFcBjyy_RkGZXw_AyZetUeE',
  );
}
