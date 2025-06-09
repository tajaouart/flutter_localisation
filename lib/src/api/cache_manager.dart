import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  final SharedPreferences _prefs;
  final Map<String, Map<String, String>> memoryCache = {};
  final Map<String, int> localVersions = {};

  CacheManager(this._prefs);

  /// Loads all data from SharedPreferences into the in-memory cache.
  Future<void> load(List<String> supportedLocales) async {
    for (final locale in supportedLocales) {
      final cachedJson = _prefs.getString('flutter_trans_$locale');
      final version = _prefs.getInt('flutter_version_$locale');

      if (cachedJson != null) {
        try {
          memoryCache[locale] =
              Map<String, String>.from(jsonDecode(cachedJson));
          localVersions[locale] = version ?? 0;
        } catch (e) {
          // Handle potential corruption of cached data.
          await clearLocale(locale);
        }
      }
    }
  }

  /// Saves new translations and version for a specific locale.
  Future<void> save(
    String locale,
    Map<String, String> translations,
    int version,
  ) async {
    memoryCache[locale] = translations;
    localVersions[locale] = version;
    await _prefs.setString('flutter_trans_$locale', jsonEncode(translations));
    await _prefs.setInt('flutter_version_$locale', version);
  }

  /// Clears all data for a specific locale.
  Future<void> clearLocale(String locale) async {
    memoryCache.remove(locale);
    localVersions.remove(locale);
    await _prefs.remove('flutter_trans_$locale');
    await _prefs.remove('flutter_version_$locale');
  }

  /// Clears all cached data for all locales.
  Future<void> clearAll() async {
    final locales = memoryCache.keys.toList();
    for (final locale in locales) {
      await clearLocale(locale);
    }
  }
}
