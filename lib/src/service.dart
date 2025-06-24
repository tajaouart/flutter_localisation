import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_localisation/src/api/api_repository.dart';
import 'package:flutter_localisation/src/api/cache_manager.dart';
import 'package:flutter_localisation/src/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  final TranslationConfig _config;
  final http.Client _httpClient;
  final ApiRepository _repository; // This can now be final, which is better

  late final CacheManager _cache;
  bool _loadingStates = false;
  bool _initialized = false;
  late final SharedPreferences prefs;
  final String? _embeddedArbTimestamp;

  TranslationService({
    final TranslationConfig? config,
    final http.Client? httpClient,
    final String? embeddedArbTimestamp,
    final ApiRepository? repository,
  })  : _config = config ?? const TranslationConfig(),
        _httpClient = httpClient ?? http.Client(),
        _embeddedArbTimestamp = embeddedArbTimestamp,
        _repository = repository ??
            ApiRepository(
              config ?? const TranslationConfig(),
              httpClient ?? http.Client(),
            );

  /// Initialize service - call this once at app start.
  Future<void> initialize({final bool fetchUpdatesOnStart = true}) async {
    if (_initialized) return;
    _log('Initializing...');

    prefs = await SharedPreferences.getInstance();
    _cache = CacheManager(prefs);

    await _cache.load(_config.supportedLocales ?? <String>[]);
    _log(
      'Cache loaded with keys for locales: ${_cache.memoryCache.keys.join(', ')}',
    );

    await _checkEmbeddedTimestampAndClearCache();

    _initialized = true;

    if (fetchUpdatesOnStart) {
      _checkForUpdatesAllLocales();
    }
  }

  /// Compare embedded ARB timestamp with cache and clear if embedded is newer
  Future<void> _checkEmbeddedTimestampAndClearCache() async {
    if (_embeddedArbTimestamp == null) {
      _log('No embedded ARB timestamp available, skipping timestamp check.');
      return;
    }

    try {
      final DateTime embeddedTime = DateTime.parse(_embeddedArbTimestamp);
      final String lastCacheUpdate = _cache.lastCacheUpdateTime;

      if (lastCacheUpdate.isEmpty) {
        _log('No previous cache timestamp found.');
        await _cache.setLastCacheUpdateTime(_embeddedArbTimestamp);
        return;
      }

      _log('Embedded ARB timestamp: $_embeddedArbTimestamp');
      _log('Last cache update: $lastCacheUpdate');

      if (embeddedTime.isAfter(DateTime.parse(lastCacheUpdate).toUtc())) {
        _log(
          'Embedded ARB is newer than cache - clearing cache due to app update.',
        );
        await _cache.clearAll();
        await _cache.setLastCacheUpdateTime(_embeddedArbTimestamp);
        _log('Cache cleared and timestamp updated.');
      } else {
        _log('Cache is up to date with embedded ARB.');
      }
    } on Exception catch (e) {
      _log('Error parsing embedded ARB timestamp: $e');
    }
  }

  /// Set the last cache update timestamp in SharedPreferences

  /// Clean up resources, like the HTTP client.
  void dispose() {
    _httpClient.close();
    _log('Service disposed.');
  }

  bool get isReady => _initialized;

  bool get isApiConfigured =>
      _config.secretKey != null && _config.projectId != null;

  String? getOverride(final String locale, final String key) =>
      _cache.memoryCache[locale]?[key];

  bool hasOverride(final String locale, final String key) =>
      _cache.memoryCache[locale]?.containsKey(key) ?? false;

  Map<String, int> getCacheStatus() => _cache.memoryCache.map(
        (final String key, final Map<String, String> value) {
          return MapEntry<String, int>(key, value.length);
        },
      );

  Future<void> clearCache() async {
    await _cache.clearAll();
    _log('Cache cleared.');
  }

  Future<void> refresh() async {
    if (!isApiConfigured) {
      _log('Cannot refresh - API not configured.');
      return;
    }
    await _fetchAndApplyUpdates(forceRefresh: true);
  }

  void _checkForUpdatesAllLocales() {
    _fetchAndApplyUpdates().catchError((final dynamic e) {
      _log('Background update failed $e');
    });
  }

  Future<void> _fetchAndApplyUpdates({final bool forceRefresh = false}) async {
    if (_loadingStates == true && !forceRefresh) return;
    _loadingStates = true;

    try {
      final String currentTimestamp = _cache.lastCacheUpdateTime;
      _log('Checking for updates from timestamp $currentTimestamp...');

      final Map<String, dynamic>? updateData =
          await _repository.fetchUpdates(currentTimestamp);

      if (updateData == null || updateData['has_updates'] != true) {
        _log('No new updates');
        return;
      }

      final String newTimestamp = updateData['last_modified'] as String;
      final Map<String, dynamic>? allTranslations =
          updateData['translations'] as Map<String, dynamic>?;

      if (allTranslations == null || allTranslations.isEmpty) {
        _log('No translations in update');
        return;
      }

      int totalUpdated = 0;
      for (final MapEntry<String, dynamic> entry in allTranslations.entries) {
        final String locale = entry.key;

        final Map<String, String> localeTranslations = <String, String>{
          for (MapEntry<String, dynamic> item
              in (entry.value as Map<String, dynamic>).entries)
            if (!item.key.startsWith('@') && item.value is String)
              item.key: item.value,
        };

        if (localeTranslations.isNotEmpty) {
          await _cache.save(locale, localeTranslations, newTimestamp);
          totalUpdated += localeTranslations.length;
          _log(
            'Updated $locale with ${localeTranslations.length} translations',
          );
        }
      }

      if (totalUpdated > 0) {
        _log(
          'Successfully updated to timestamp $newTimestamp with $totalUpdated total translations.',
        );
      }
    } on Exception catch (e) {
      _log('Error during update process: $e');
    } finally {
      _loadingStates = false;
    }
  }

  void _log(final String message) {
    if (_config.enableLogging) {
      debugPrint('[FlutterLocalisation] $message');
    }
  }

  Map<String, String> getAllOverridesForLocale(final String locale) {
    return Map<String, String>.from(
      _cache.memoryCache[locale] ?? <dynamic, dynamic>{},
    );
  }

  bool get isLoggingEnabled => _config.enableLogging;

  /// Get the embedded ARB timestamp
  String? get embeddedArbTimestamp => _embeddedArbTimestamp;
}
