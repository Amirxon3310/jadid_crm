abstract final class AppConfig {
  /// Whether accounts are created by the `create-account` edge function.
  ///
  /// Off until that function is deployed. Creating an account in the browser
  /// signs it in, and on the web gotrue tells every client in the browser, so
  /// the admin doing the work is thrown into the new account — the app puts
  /// their session back, but the server-side path avoids it happening at all.
  /// Deploy `supabase/functions/create-account`, then turn this on.
  static const useServerAccountCreation = false;

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
