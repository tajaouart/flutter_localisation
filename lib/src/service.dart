import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Main service for managing SaaS-based translation overrides
class SaaSTranslationService {
  final Map<String, Map<String, String>> _memoryCache = {};
  final Map<String, bool> _loadingStates = {};
  final SaaSTranslationConfig _config;

  // Version tracking
  final Map<String, int> _localVersions = {};
  late SharedPreferences _prefs;
  bool _initialized = false;

  // HTTP client for API calls
  final http.Client _httpClient;

  SaaSTranslationService({
    SaaSTranslationConfig? config,
    http.Client? httpClient,
  })  : _config = config ?? const SaaSTranslationConfig(),
        _httpClient = httpClient ?? http.Client();

  /// Initialize service - call this once at app start
  Future<void> initialize() async {
    if (_initialized) return;

    _log('Initializing SaaS Translation Service...');
    _prefs = await SharedPreferences.getInstance();

    // Load cached translations into memory (BLOCKING - ensures data is ready)
    await _loadCachedTranslations();
    _log('Cache loaded, app can render with cached translations');

    _initialized = true;

    // Only check for updates if we have API credentials (paid users)
    if (_config.secretKey != null &&
        _config.projectId != null &&
        _config.flavorName != null) {
      // Check for updates in background (NON-BLOCKING - happens after app starts)
      Future.delayed(const Duration(milliseconds: 100), () {
        _checkForUpdatesAllLocales();
      });
    } else {
      _log('No API credentials configured - running in offline mode');
    }

    _log('Service initialized');
  }

  /// Check if service is ready with cached data
  bool get isReady => _initialized && _memoryCache.isNotEmpty;

  /// Check if API is configured (for paid users)
  bool get isApiConfigured =>
      _config.secretKey != null &&
      _config.projectId != null &&
      _config.flavorName != null;

  /// Get override translation for a specific key
  /// This is INSTANT - reads from memory cache, no async needed
  String? getOverride(String locale, String key) {
    return _memoryCache[locale]?[key];
  }

  /// Check if there's an override for a specific key
  /// This is INSTANT - reads from memory cache
  bool hasOverride(String locale, String key) {
    return _memoryCache[locale]?.containsKey(key) ?? false;
  }

  /// Force refresh translations for a locale
  Future<void> refreshTranslations(String locale) async {
    if (!isApiConfigured) {
      _log('Cannot refresh - API not configured');
      return;
    }
    await _checkAndFetchUpdates(locale, forceRefresh: true);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    _memoryCache.clear();
    _localVersions.clear();

    // Clear from persistent storage
    final keys = _prefs.getKeys().where((key) =>
        key.startsWith('saas_trans_') || key.startsWith('saas_version_'));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// Get cache status for debugging
  Map<String, int> getCacheStatus() {
    return _memoryCache
        .map((locale, overrides) => MapEntry(locale, overrides.length));
  }

  Future<void> _loadCachedTranslations() async {
    final stopwatch = Stopwatch()..start();
    final locales = _config.supportedLocales ?? ['en', 'es'];

    for (final locale in locales) {
      final cached = _prefs.getString('saas_trans_$locale');
      final version = _prefs.getInt('saas_version_$locale');

      if (cached != null) {
        try {
          final translations = Map<String, String>.from(jsonDecode(cached));
          _memoryCache[locale] = translations;
          _localVersions[locale] = version ?? 0;
          _log('Loaded ${translations.length} cached translations for $locale');
        } catch (e) {
          _log('Error loading cached translations for $locale: $e');
        }
      }
    }

    stopwatch.stop();
    _log('Cache loaded in ${stopwatch.elapsedMilliseconds}ms');
  }

  Future<void> _checkForUpdatesAllLocales() async {
    final locales = _config.supportedLocales ?? ['en', 'es'];

    for (final locale in locales) {
      // Non-blocking background check
      _checkAndFetchUpdates(locale).catchError((e) {
        _log('Background update failed for $locale: $e');
      });
    }
  }

  Future<void> _checkAndFetchUpdates(
    String locale, {
    bool forceRefresh = false,
  }) async {
    if (!isApiConfigured) return;

    if (_loadingStates[locale] == true && !forceRefresh) {
      return;
    }

    _loadingStates[locale] = true;

    try {
      final currentVersion = _localVersions[locale] ?? 0;

      // Make API call to check for updates
      final updateData = await _fetchTranslationUpdates(locale, currentVersion);

      if (updateData == null || !updateData['has_updates']) {
        _log('No updates available for $locale');
        return;
      }

      // Extract translations based on locale
      final allTranslations =
          updateData['translations'] as Map<String, dynamic>?;
      if (allTranslations == null) {
        _log('No translations in response');
        return;
      }

      // Get translations for the specific locale
      final localeTranslations =
          allTranslations[locale] as Map<String, dynamic>?;
      if (localeTranslations == null) {
        _log('No translations for locale $locale');
        return;
      }

      // Convert to Map<String, String>
      final translations = localeTranslations.map(
        (key, value) => MapEntry(key, value.toString()),
      );

      // Update memory cache
      _memoryCache[locale] = translations;
      _localVersions[locale] = updateData['version'] as int;

      // Persist to storage
      await _persistTranslations(locale, {
        'translations': translations,
        'version': updateData['version'],
      });

      _log(
          'Updated ${translations.length} translations for $locale to version ${updateData['version']}');
    } catch (e) {
      _log('Error updating translations for $locale: $e');
      if (_config.throwOnError && forceRefresh) rethrow;
    } finally {
      _loadingStates[locale] = false;
    }
  }

  Future<Map<String, dynamic>?> _fetchTranslationUpdates(
      String locale, int currentVersion) async {
    if (!isApiConfigured) return null;

    try {
      final uri =
          Uri.parse('${_config.apiBaseUrl}/api/v1/translations/live-update/');

      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer ${_config.secretKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'project_id': _config.projectId,
              'flavor': _config.flavorName,
              'current_version': currentVersion,
            }),
          )
          .timeout(_config.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      // Handle specific error cases
      if (response.statusCode == 401) {
        _log('Authentication failed - check your API key');
      } else if (response.statusCode == 404) {
        _log('Project or flavor not found');
      } else if (response.statusCode == 429) {
        _log('Rate limit exceeded');
      } else if (response.statusCode == 500) {
        _log('Server error: ${response.body}');
      }

      return null;
    } catch (e) {
      _log('Failed to fetch translations: $e');
      return null;
    }
  }

  Future<void> _persistTranslations(
    String locale,
    Map<String, dynamic> data,
  ) async {
    try {
      await _prefs.setString(
          'saas_trans_$locale', jsonEncode(data['translations']));
      await _prefs.setInt('saas_version_$locale', data['version'] as int);
      await _prefs.setString(
          'saas_last_update_$locale', DateTime.now().toIso8601String());
    } catch (e) {
      _log('Failed to persist translations for $locale: $e');
    }
  }

  void _log(String message) {
    if (_config.enableLogging) {
      debugPrint('[SaaSTranslations] $message');
    }
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
  }
}
