// lib/src/config.dart

/// Configuration for SaaS Translation Service
class SaaSTranslationConfig {
  /// Timeout for API calls
  final Duration apiTimeout;

  /// Enable debug logging
  final bool enableLogging;

  /// Throw exceptions on API errors (vs silent fail)
  final bool throwOnError;

  /// Path to generated app_localizations.dart (auto-detected if null)
  final String? localizationsPath;

  /// Path where generated methods should be written (auto-detected if null)
  final String? outputPath;

  const SaaSTranslationConfig({
    this.apiTimeout = const Duration(seconds: 5),
    this.enableLogging = true,
    this.throwOnError = false,
    this.localizationsPath,
    this.outputPath,
  });

  /// Create config with custom API integration
  const SaaSTranslationConfig.production({
    this.apiTimeout = const Duration(seconds: 10),
    this.enableLogging = false,
    this.throwOnError = true,
    this.localizationsPath,
    this.outputPath,
  });

  /// Create config for development/demo
  const SaaSTranslationConfig.development({
    this.apiTimeout = const Duration(seconds: 2),
    this.enableLogging = true,
    this.throwOnError = false,
    this.localizationsPath,
    this.outputPath,
  });
}
