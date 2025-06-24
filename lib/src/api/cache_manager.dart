import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  final SharedPreferences _prefs;
  final Map<String, Map<String, String>> memoryCache =
      <String, Map<String, String>>{};
  final Map<String, String> localTimestamps = <String, String>{};
  String _lastCacheUpdateTime = '';

  String get lastCacheUpdateTime => _lastCacheUpdateTime;

  CacheManager(this._prefs);

  /// Loads all data from SharedPreferences into the in-memory cache.
  Future<void> load(final List<String> supportedLocales) async {
    for (final String locale in supportedLocales) {
      final String? cachedJson = _prefs.getString('flutter_trans_$locale');

      if (cachedJson != null) {
        try {
          memoryCache[locale] =
              Map<String, String>.from(jsonDecode(cachedJson));

          final String? timestamp = _prefs.getString('flutter_version_$locale');
          localTimestamps[locale] = timestamp ?? '';
        } on Exception catch (_) {
          await clearLocale(locale);
        }
      }
    }

    _lastCacheUpdateTime = await _getLastCacheUpdateTime();
  }

  /// Saves new translations and timestamp for a specific locale.
  Future<void> save(
    final String locale,
    final Map<String, String> translations,
    final String timestamp,
  ) async {
    memoryCache[locale] = translations;
    localTimestamps[locale] = timestamp;
    await _prefs.setString('flutter_trans_$locale', jsonEncode(translations));
    await _prefs.setString('flutter_version_$locale', timestamp);
    await setLastCacheUpdateTime(timestamp);
  }

  /// Clears all data for a specific locale.
  Future<void> clearLocale(final String locale) async {
    memoryCache.remove(locale);
    localTimestamps.remove(locale);
    await _prefs.remove('flutter_trans_$locale');
    await _prefs.remove('flutter_version_$locale');
    _lastCacheUpdateTime = '';
  }

  /// Clears all cached data for all locales.
  Future<void> clearAll() async {
    final List<String> locales = memoryCache.keys.toList();
    localTimestamps.clear();
    for (final String locale in locales) {
      await clearLocale(locale);
    }
    setLastCacheUpdateTime('');
  }

  /// Get the last cache update timestamp from SharedPreferences
  Future<String> _getLastCacheUpdateTime() async {
    try {
      _lastCacheUpdateTime =
          _prefs.getString('flutter_localisation_cache_timestamp') ?? '';
      return _lastCacheUpdateTime;
    } on Exception catch (_) {
      return '';
    }
  }

  Future<void> setLastCacheUpdateTime(final String timestamp) async {
    await _prefs.setString(
      'flutter_localisation_cache_timestamp',
      timestamp,
    );
    await _getLastCacheUpdateTime();
  }
}
