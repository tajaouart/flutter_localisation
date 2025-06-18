import 'package:flutter/widgets.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_localisation/src/icu_message_processor.dart';

/// Main class that handles translation resolution with FlutterLocalisation overrides.
///
/// This class is designed to be short-lived, created by `context.tr` when needed.
/// It contains an internal cache for the ICUMessageProcessor to improve performance.
class Translator {
  final BuildContext context;
  final TranslationService service;
  final dynamic generatedLocalizations;

  // Internal cache for the expensive-to-create ICU message processor.
  ICUMessageProcessor? _cachedProcessor;

  Translator({
    required this.context,
    required this.service,
    required this.generatedLocalizations,
  });

  /// The core translation method.
  ///
  /// It first checks the FlutterLocalisation for an override. If one exists,
  /// it processes it using an optimized ICU message processor. Otherwise, it
  /// falls back to the standard generated translation.
  String translate(
    String key,
    Map<String, dynamic> arguments,
    String Function() fallbackGenerator,
  ) {
    final locale = Localizations.localeOf(context);
    final overrideTemplate = service.getOverride(locale.languageCode, key);

    if (overrideTemplate != null) {
      // An override exists, process it efficiently.
      return _processFlutterLocalisationOverride(
          key, overrideTemplate, arguments);
    }

    // No override found, use the standard generated translation.
    return fallbackGenerator();
  }

  /// Efficiently processes a FlutterLocalisation override string.
  ///
  /// It lazily creates and caches an ICUMessageProcessor instance for the current
  /// locale, avoiding repeated creation for multiple translations on the same screen.
  String _processFlutterLocalisationOverride(
    String key,
    String template,
    Map<String, dynamic> args,
  ) {
    try {
      final locale = Localizations.localeOf(context);

      // --- PERFORMANCE OPTIMIZATION ---
      // If our cached processor is null or for a different locale, create a new one.
      if (_cachedProcessor == null || _cachedProcessor?.locale != locale) {
        // Fetch ALL overrides for the current locale at once.
        final allOverridesForLocale =
            service.getAllOverridesForLocale(locale.languageCode);

        // Create a single, powerful processor for all of them.
        _cachedProcessor = ICUMessageProcessor(
          locale,
          allOverridesForLocale,
          {}, // Metadata can be added later if needed.
        );
        _log(
            'Created and cached ICUMessageProcessor for ${locale.languageCode}');
      }

      // Use the cached processor to get the final string.
      return _cachedProcessor!.getString(key, args);
    } catch (e) {
      _log('Error processing ICU override for key "$key": $e');
      // Fallback to basic replacement if ICU processing fails.
      return _basicPlaceholderReplacement(template, args);
    }
  }

  /// A simple fallback for placeholder replacement if ICU fails.
  String _basicPlaceholderReplacement(
    String template,
    Map<String, dynamic> args,
  ) {
    String result = template;
    args.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }

  void _log(String message) {
    if (service.isLoggingEnabled) {
      debugPrint('[Translator] $message');
    }
  }

  Future<void> refresh() async {
    await service.refresh(
      Localizations.localeOf(context).languageCode,
    );
  }

  Map<String, int> get cacheStatus => service.getCacheStatus();
}
