abstract final class AppConfig {
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
