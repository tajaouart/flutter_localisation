import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Main service for managing SaaS-based translation overrides
class SaaSTranslationService {
  final Map<String, Map<String, String>> _memoryCache = {};
  final Map<String, bool> _loadingStates = {};
  final SaaSTranslationConfig _config;

  // Version tracking
  final Map<String, String> _localVersions = {};
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Mock version for demo
  static const String _mockServerVersion = '1.0.1';

  SaaSTranslationService({
    SaaSTranslationConfig? config,
  }) : _config = config ?? SaaSTranslationConfig();

  /// Initialize service - call this once at app start
  Future<void> initialize() async {
    if (_initialized) return;

    _log('Initializing SaaS Translation Service...');
    _prefs = await SharedPreferences.getInstance();

    // Load cached translations into memory (BLOCKING - ensures data is ready)
    await _loadCachedTranslations();
    _log('Cache loaded, app can render with cached translations');

    _initialized = true;

    // Check for updates in background (NON-BLOCKING - happens after app starts)
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkForUpdatesAllLocales();
    });

    _log('Service initialized');
  }

  /// Check if service is ready with cached data
  bool get isReady => _initialized && _memoryCache.isNotEmpty;

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
      final version = _prefs.getString('saas_version_$locale');

      if (cached != null) {
        try {
          final translations = Map<String, String>.from(jsonDecode(cached));
          _memoryCache[locale] = translations;
          _localVersions[locale] = version ?? '0';
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
    if (_loadingStates[locale] == true && !forceRefresh) {
      return;
    }

    _loadingStates[locale] = true;

    try {
      // First, check if update needed (lightweight HEAD request)
      final currentVersion = _localVersions[locale] ?? '0';
      final shouldUpdate =
          forceRefresh || await _checkVersionUpdate(locale, currentVersion);

      if (!shouldUpdate) {
        _log('No updates available for $locale');
        return;
      }

      // Fetch updates (delta or full based on API tier)
      final updates = await _fetchTranslationUpdates(locale, currentVersion);

      if (updates.isEmpty) return;

      // Update memory cache
      _memoryCache[locale] = updates['translations'] as Map<String, String>;
      _localVersions[locale] = updates['version'] as String;

      // Persist to storage
      await _persistTranslations(locale, updates);

      _log('Updated ${_memoryCache[locale]!.length} translations for $locale');
    } catch (e) {
      _log('Error updating translations for $locale: $e');
      if (_config.throwOnError && forceRefresh) rethrow;
    } finally {
      _loadingStates[locale] = false;
    }
  }

  Future<bool> _checkVersionUpdate(String locale, String currentVersion) async {
    // MOCK: Simulate API delay and version check
    await Future.delayed(const Duration(milliseconds: 300));
    _log(
        '[MOCK] Version check for $locale: current=$currentVersion, server=$_mockServerVersion');
    return currentVersion != _mockServerVersion;

    // REAL API CODE (commented out for mock)
    /*
    try {
      final uri =
          Uri.parse('${_config.apiBaseUrl}/translations/$locale/version');
      final response = await http
          .head(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(_config.apiTimeout);

      if (response.statusCode == 200) {
        final serverVersion = response.headers['x-version'] ?? '0';
        return serverVersion != currentVersion;
      }

      return false;
    } catch (e) {
      _log('Version check failed for $locale: $e');
      return false;
    }
    */
  }

  Future<Map<String, dynamic>> _fetchTranslationUpdates(
      String locale, String currentVersion) async {
    // MOCK: Return mock data based on locale
    await Future.delayed(const Duration(milliseconds: 500));

    Map<String, String> mockTranslations;

    if (locale == 'en') {
      mockTranslations = {
        'appTitle': '🇺🇸 USA App',
        'hello': '🇺🇸 Hello {name}!',
        'welcomeMessage': '🇺🇸 Welcome back, {username}!',
        'simpleGreeting': '🇺🇸 Good morning!',
        'itemsInCart':
            '{count, plural, =0{ 🇺🇸 No items} =1{🇺🇸 1 item} other{🇺🇸 {count} items}}',
        'refreshButton': 'Refresh Translations',
      };
    } else if (locale == 'es') {
      mockTranslations = {
        'appTitle': '🇪🇸 Aplicación España',
        'hello': '🇪🇸 ¡Hola {name}!',
        'welcomeMessage': '🇪🇸 ¡Bienvenido de nuevo, {username}!',
        'simpleGreeting': '🇪🇸 ¡Buenos días!',
        'itemsInCart':
            '{count, plural, =0{🇪🇸 Sin artículos} =1{🇪🇸 1 artículo} other{🇪🇸 {count} artículos}}',
        'refreshButton': '🇪🇸 Actualizar Traducciones',
      };
    } else {
      mockTranslations = {};
    }

    _log('[MOCK] Fetched ${mockTranslations.length} translations for $locale');

    return {
      'translations': mockTranslations,
      'version': _mockServerVersion,
    };

    // REAL API CODE (commented out for mock)
    /*
    try {
      // Determine endpoint based on API tier
      final endpoint = _config.apiKey != null && currentVersion != '0'
          ? '/translations/$locale/delta?from=$currentVersion'
          : '/translations/$locale/full';

      final uri = Uri.parse('${_config.apiBaseUrl}$endpoint');
      final response = await http
          .get(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(_config.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle delta updates
        if (endpoint.contains('delta')) {
          final existing = Map<String, String>.from(_memoryCache[locale] ?? {});
          final updates = Map<String, String>.from(data['updates'] ?? {});
          final deletions = List<String>.from(data['deletions'] ?? []);

          // Apply updates
          existing.addAll(updates);

          // Remove deletions
          for (final key in deletions) {
            existing.remove(key);
          }

          return {
            'translations': existing,
            'version': data['version'] ?? currentVersion,
          };
        }

        // Full replacement
        return {
          'translations': Map<String, String>.from(data['translations'] ?? {}),
          'version': data['version'] ?? currentVersion,
        };
      }

      // Handle rate limiting
      if (response.statusCode == 429) {
        _log('Rate limit exceeded for $locale');
        // Could implement exponential backoff here
      }

      return {};
    } catch (e) {
      _log('Failed to fetch translations for $locale: $e');
      return {};
    }
    */
  }

  Future<void> _persistTranslations(
    String locale,
    Map<String, dynamic> data,
  ) async {
    try {
      await _prefs.setString(
          'saas_trans_$locale', jsonEncode(data['translations']));
      await _prefs.setString('saas_version_$locale', data['version'] as String);
      await _prefs.setString(
          'saas_last_update_$locale', DateTime.now().toIso8601String());
    } catch (e) {
      _log('Failed to persist translations for $locale: $e');
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (_config.apiKey != null) {
      headers['Authorization'] = 'Bearer ${_config.apiKey}';
    }

    // Add client info for analytics
    headers['X-Client-Version'] = '1.0.0';
    headers['X-Platform'] = defaultTargetPlatform.toString();

    return headers;
  }

  void _log(String message) {
    if (_config.enableLogging) {
      debugPrint('[SaaSTranslations] $message');
    }
  }
}
