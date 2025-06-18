import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_localisation/src/api/api_repository.dart';
import 'package:flutter_localisation/src/api/cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class TranslationService {
  final TranslationConfig _config;
  final http.Client _httpClient;

  late final ApiRepository _repository;
  late final CacheManager _cache;

  final Map<String, bool> _loadingStates = {};
  bool _initialized = false;

  TranslationService({
    TranslationConfig? config,
    http.Client? httpClient,
  })  : _config = config ?? const TranslationConfig(),
        _httpClient = httpClient ?? http.Client() {
    _repository = ApiRepository(_config, _httpClient);
  }

  /// Initialize service - call this once at app start.
  Future<void> initialize() async {
    if (_initialized) return;
    _log('Initializing...');

    final prefs = await SharedPreferences.getInstance();
    _cache = CacheManager(prefs);

    await _cache.load(_config.supportedLocales ?? []);
    _log(
      'Cache loaded with keys for locales: ${_cache.memoryCache.keys.join(', ')}',
    );

    _initialized = true;

    _checkForUpdatesAllLocales();
  }

  /// Clean up resources, like the HTTP client.
  void dispose() {
    _httpClient.close();
    _log('Service disposed.');
  }

  bool get isReady => _initialized;

  bool get isApiConfigured =>
      _config.secretKey != null && _config.projectId != null;

  String? getOverride(String locale, String key) =>
      _cache.memoryCache[locale]?[key];

  bool hasOverride(String locale, String key) =>
      _cache.memoryCache[locale]?.containsKey(key) ?? false;

  Map<String, int> getCacheStatus() =>
      _cache.memoryCache.map((key, value) => MapEntry(key, value.length));

  Future<void> clearCache() async {
    await _cache.clearAll();
    _log('Cache cleared.');
  }

  Future<void> refresh(String locale) async {
    if (!isApiConfigured) {
      _log('Cannot refresh - API not configured.');
      return;
    }
    await _fetchAndApplyUpdates(locale, forceRefresh: true);
  }

  void _checkForUpdatesAllLocales() {
    final locales = _config.supportedLocales ?? [];
    for (final locale in locales) {
      _fetchAndApplyUpdates(locale).catchError((e) {
        _log('Background update failed for $locale: $e');
      });
    }
  }

  Future<void> _fetchAndApplyUpdates(
    String locale, {
    bool forceRefresh = false,
  }) async {
    if (_loadingStates[locale] == true && !forceRefresh) return;
    _loadingStates[locale] = true;

    try {
      final currentVersion = _cache.localVersions[locale] ?? "";
      _log('Checking for updates for $locale from version $currentVersion...');

      final updateData = await _repository.fetchUpdates(currentVersion);

      if (updateData == null || updateData['has_updates'] != true) {
        _log('No new updates for $locale.');
        return;
      }

      final newVersion = updateData['version'] as String;
      final allTranslations =
          updateData['translations'] as Map<String, dynamic>?;

      final newTranslations = Map<String, String>.from(
        allTranslations?[locale] as Map? ?? {},
      );

      if (newTranslations.isNotEmpty) {
        await _cache.save(locale, newTranslations, newVersion);
        _log(
          'Successfully updated $locale to version $newVersion with ${newTranslations.length} keys.',
        );
      }
    } catch (e) {
      _log('Error during update process for $locale: $e');
    } finally {
      _loadingStates[locale] = false;
    }
  }

  void _log(String message) {
    if (_config.enableLogging) {
      debugPrint('[FlutterLocalisation] $message');
    }
  }

  Map<String, String> getAllOverridesForLocale(String locale) {
    return Map<String, String>.from(_cache.memoryCache[locale] ?? {});
  }

  bool get isLoggingEnabled => _config.enableLogging;
}
