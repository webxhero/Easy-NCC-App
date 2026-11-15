/// App-wide configuration.
///
/// Add the Supabase Project URL and Publishable Key here once.
/// These are client-side values. Never place a Supabase secret/service_role key
/// in a Flutter application.
class AppConfig {
  AppConfig._();

  static bool supabaseInitialized = false;

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://djyktlocjmwxmpvylslf.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ObrmthvU8sQwFWp1uBzvlA_jbXTKJZ_',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_REF') &&
      !supabasePublishableKey.contains('YOUR_');

  static bool get isSupabaseReady =>
      isSupabaseConfigured && supabaseInitialized;
}
