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

  /// Creates a translation configuration with custom settings
  ///
  /// For most use cases, prefer [TranslationConfig.freeUser] or [TranslationConfig.paidUser]
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
    final List<String>? supportedLocales,
    final bool enableLogging = false,
  }) {
    return TranslationConfig(
      supportedLocales: supportedLocales,
      enableLogging: enableLogging,
    );
  }

  /// Factory constructor for paid users with API access
  factory TranslationConfig.paidUser({
    required final String secretKey,
    required final String flavorName,
    required final int projectId,
    final String apiBaseUrl = 'http://localhost:8000',
    final Duration apiTimeout = const Duration(seconds: 10),
    final List<String>? supportedLocales,
    final bool enableLogging = true,
    final bool throwOnError = false,
    final Duration? backgroundCheckInterval,
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
