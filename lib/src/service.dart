// lib/src/service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'config.dart';

/// Main service for managing SaaS-based translation overrides
///
/// This service automatically integrates with any Flutter app's localizations
class SaaSTranslationService with ChangeNotifier {
  final SaaSTranslationConfig _config;
  final Map<String, Map<String, String>> _overrides = {};
  final Map<String, bool> _loadingStates = {};

  SaaSTranslationService({
    SaaSTranslationConfig? config,
  }) : _config = config ?? SaaSTranslationConfig();

  /// Fetch translation updates from your API
  ///
  /// Override this method to integrate with your actual API
  Future<void> fetchUpdates(String locale) async {
    if (_loadingStates[locale] == true) {
      _log('Already fetching updates for $locale');
      return;
    }

    _loadingStates[locale] = true;
    _log('Fetching translation updates for $locale...');

    try {
      final overrides = await _fetchFromAPI(locale);
      final hasChanges = _updateOverrides(locale, overrides);

      if (hasChanges) {
        _log('Applied ${overrides.length} overrides for $locale');
        notifyListeners();
      }
    } catch (error) {
      _log('Error fetching translations for $locale: $error');
      if (_config.throwOnError) rethrow;
    } finally {
      _loadingStates[locale] = false;
    }
  }

  /// Get override translation for a specific key
  String? getOverride(String locale, String key) {
    return _overrides[locale]?[key];
  }

  /// Check if there's an override for a specific key
  bool hasOverride(String locale, String key) {
    return _overrides[locale]?.containsKey(key) ?? false;
  }

  /// Clear all cached overrides
  void clearCache() {
    _overrides.clear();
    notifyListeners();
  }

  /// Get cache status for debugging
  Map<String, int> getCacheStatus() {
    return _overrides
        .map((locale, overrides) => MapEntry(locale, overrides.length));
  }

  // Override this method to integrate with your API
  Future<Map<String, String>> _fetchFromAPI(String locale) async {
    await Future.delayed(_config.apiTimeout);

    // Demo implementation with complex ICU examples - replace with your API call
    if (locale == 'en') {
      return {
        'hello': '🚀 SaaS Hello {name}!',
        'welcomeMessage': '🎉 SaaS Welcome back, {username}!',
        'appTitle': '🔥 SaaS Translation Demo',
        'simpleGreeting': '✨ SaaS Good morning!',
        'refreshButton': '🔄 SaaS Refresh Translations',
        // Complex ICU examples that AppLocalizations2 can handle
        'itemsInCart':
            '{count, plural, =0{🛒 SaaS: No items in cart} =1{🛒 SaaS: 1 amazing item} other{🛒 SaaS: {count} amazing items}}',
      };
    } else if (locale == 'es') {
      return {
        'hello': '🚀 SaaS ¡Hola {name}!',
        'welcomeMessage': '🎉 SaaS ¡Bienvenido de vuelta, {username}!',
        'appTitle': '🔥 SaaS Demo de Traducciones',
        'simpleGreeting': '✨ SaaS ¡Buenos días!',
        'refreshButton': '🔄 SaaS Actualizar Traducciones',
        // Complex ICU examples in Spanish
        'itemsInCart':
            '{count, plural, =0{🛒 SaaS: Sin artículos en carrito} =1{🛒 SaaS: 1 artículo increíble} other{🛒 SaaS: {count} artículos increíbles}}',
      };
    }

    return {};
  }

  bool _updateOverrides(String locale, Map<String, String> newOverrides) {
    final current = _overrides[locale] ?? {};

    if (_mapsEqual(current, newOverrides)) {
      return false;
    }

    if (newOverrides.isEmpty) {
      _overrides.remove(locale);
    } else {
      _overrides[locale] = Map.from(newOverrides);
    }

    return true;
  }

  bool _mapsEqual(Map<String, String> map1, Map<String, String> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  void _log(String message) {
    if (_config.enableLogging) {
      debugPrint('[SaaSTranslations] $message');
    }
  }
}
