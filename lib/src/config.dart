/// Configuration for FlutterLocalisation translation service behavior
class TranslationConfig {
  /// The flavor name (e.g., 'default', 'premium')
  final String? flavorName;

  /// The API key for authentication (e.g., 'sk_live_xxxxx')
  final String? secretKey;

  /// The project ID from your Django backend
  final int? projectId;

  /// Supported locales to check for updates
  final List<String>? supportedLocales;

  /// Whether to enable debug logging
  final bool enableLogging;

  /// How often to check for updates in the background (null = disabled)
  final Duration? backgroundCheckInterval;

  const TranslationConfig({
    this.secretKey,
    this.flavorName,
    this.projectId,
    this.supportedLocales,
    this.enableLogging = true,
    this.backgroundCheckInterval,
  });

  /// Factory constructor for free users (no API access)
  factory TranslationConfig.freeUser({
    List<String>? supportedLocales,
    bool enableLogging = false,
  }) {
    return TranslationConfig(
      secretKey: null,
      flavorName: null,
      projectId: null,
      supportedLocales: supportedLocales,
      enableLogging: enableLogging,
    );
  }

  /// Factory constructor for paid users with API access
  factory TranslationConfig.paidUser({
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
    return TranslationConfig(
      secretKey: secretKey,
      flavorName: flavorName,
      projectId: projectId,
      supportedLocales: supportedLocales,
      enableLogging: enableLogging,
      backgroundCheckInterval: backgroundCheckInterval,
    );
  }
}
