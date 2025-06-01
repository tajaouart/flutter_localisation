// lib/src/config.dart
import 'package:flutter/foundation.dart';

/// Configuration for SaaS translation service behavior
class SaaSTranslationConfig {
  /// Enable console logging for debugging
  final bool enableLogging;

  /// Timeout for API calls
  final Duration apiTimeout;

  /// Whether to throw errors or fail silently
  final bool throwOnError;

  /// Base URL for translation API
  final String apiBaseUrl;

  /// API key for authenticated requests (null for free tier)
  final String? apiKey;

  /// Supported locales to check for updates
  final List<String>? supportedLocales;

  /// Path to generated app_localizations.dart (auto-detected if null)
  final String? localizationsPath;

  /// Path where generated methods should be written (auto-detected if null)
  final String? outputPath;

  const SaaSTranslationConfig({
    this.enableLogging = false,
    this.apiTimeout = const Duration(seconds: 5),
    this.throwOnError = false,
    this.apiBaseUrl = 'https://api.yoursaas.com',
    this.apiKey,
    this.supportedLocales,
    this.localizationsPath,
    this.outputPath,
  });

  /// Create config for production environment
  const SaaSTranslationConfig.production({
    required this.apiBaseUrl,
    required this.apiKey,
    this.supportedLocales,
    this.enableLogging = false,
    this.apiTimeout = const Duration(seconds: 10),
    this.throwOnError = true,
    this.localizationsPath,
    this.outputPath,
  });

  /// Create config for development/demo
  const SaaSTranslationConfig.development({
    this.apiBaseUrl = 'https://dev-api.yoursaas.com',
    this.apiKey,
    this.supportedLocales,
    this.enableLogging = true,
    this.apiTimeout = const Duration(seconds: 10),
    this.throwOnError = kDebugMode,
    this.localizationsPath,
    this.outputPath,
  });
}
