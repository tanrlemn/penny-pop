class Env {
  static String get supabaseUrl => const String.fromEnvironment('SUPABASE_URL');

  // Supabase is increasingly labeling this as "Publishable key" (sb_publishable_...).
  static String get supabasePublishableKey =>
      const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static String get supabaseKey => supabasePublishableKey;

  static String get googleIosClientId =>
      const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static String get googleWebClientId =>
      const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static String get backendBaseUrl =>
      const String.fromEnvironment('BACKEND_BASE_URL');
}
