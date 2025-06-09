/// Configuration for SaaS translation service behavior
class SaaSTranslationConfig {
  /// The flavor name (e.g., 'default', 'premium')
  final String? flavorName;

  /// The API key for authentication (e.g., 'sk_live_xxxxx')
  final String? secretKey;

  /// The project ID from your Django backend
  final int? projectId;

  /// Base URL for the API (defaults to localhost for development)
  final String apiBaseUrl;

  /// Timeout for API calls
  final Duration apiTimeout;

  /// Supported locales to check for updates
  final List<String>? supportedLocales;

  /// Whether to enable debug logging
  final bool enableLogging;

  /// Whether to throw errors or fail silently
  final bool throwOnError;

  /// How often to check for updates in the background (null = disabled)
  final Duration? backgroundCheckInterval;

  const SaaSTranslationConfig({
    this.secretKey,
    this.flavorName,
    this.projectId,
    this.apiBaseUrl = 'http://localhost:8000', // Change to your production URL
    this.apiTimeout = const Duration(seconds: 10),
    this.supportedLocales,
    this.enableLogging = true,
    this.throwOnError = false,
    this.backgroundCheckInterval,
  });

  /// Factory constructor for free users (no API access)
  factory SaaSTranslationConfig.freeUser({
    List<String>? supportedLocales,
    bool enableLogging = false,
  }) {
    return SaaSTranslationConfig(
      secretKey: null,
      flavorName: null,
      projectId: null,
      supportedLocales: supportedLocales,
      enableLogging: enableLogging,
    );
  }

  /// Factory constructor for paid users with API access
  factory SaaSTranslationConfig.paidUser({
    required String secretKey,
    required String flavorName,
    required int projectId,
    String apiBaseUrl = 'http://localhost:8000',
    Duration apiTimeout = const Duration(seconds: 10),
    List<String>? supportedLocales,
    bool enableLogging = true,
    bool throwOnError = false,
    Duration? backgroundCheckInterval,
  }) {
    return SaaSTranslationConfig(
      secretKey: secretKey,
      flavorName: flavorName,
      projectId: projectId,
      apiBaseUrl: apiBaseUrl,
      apiTimeout: apiTimeout,
      supportedLocales: supportedLocales,
      enableLogging: enableLogging,
      throwOnError: throwOnError,
      backgroundCheckInterval: backgroundCheckInterval,
    );
  }
}
