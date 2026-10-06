class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
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
    defaultValue: 'http://localhost:8080',
  );
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'http://localhost:8080/auth',
  );

  static const termsVersion = '2026-10-05';
  static const minimumAccountAge = 18;

  static String get supabaseClientKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : legacyAnonKey;

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
