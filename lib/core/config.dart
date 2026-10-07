class AppConfig {
  static const appEnvironment = String.fromEnvironment('APP_ENV', defaultValue: 'staging');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://qmuyrobiqowcjgbpyliv.supabase.co');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW',
  );
  static const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const legalOwner = String.fromEnvironment(
    'LEGAL_OWNER',
    defaultValue: 'PENDIENTE DE COMPLETAR',
  );
  static const legalEmail = String.fromEnvironment(
    'LEGAL_EMAIL',
    defaultValue: 'PENDIENTE DE COMPLETAR',
  );
  static const legalAddress = String.fromEnvironment(
    'LEGAL_ADDRESS',
    defaultValue: 'PENDIENTE DE COMPLETAR',
  );
  static const websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://gratiscashv1.vercel.app',
  );
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'https://gratiscashv1.vercel.app/auth',
  );
  static const googleAuthEnabled = bool.fromEnvironment(
    'GOOGLE_AUTH_ENABLED',
    defaultValue: false,
  );

  static const termsVersion = '2026-10-06';
  static const minimumAccountAge = 18;

  static String get supabaseClientKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : legacyAnonKey;

  static bool get isProduction => appEnvironment.toLowerCase() == 'production';

  static bool get backendConfigured =>
      supabaseUrl.startsWith('https://') && supabaseClientKey.isNotEmpty;

  static bool get legalConfigured =>
      !_isPlaceholder(legalOwner) &&
      !_isPlaceholder(legalEmail) &&
      !_isPlaceholder(legalAddress);

  static bool _isPlaceholder(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.isEmpty || normalized.contains('PENDIENTE');
  }
}
