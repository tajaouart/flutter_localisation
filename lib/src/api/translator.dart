import 'package:flutter/widgets.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_localisation/src/api/locale_keys.dart';
import 'package:flutter_localisation/src/icu_message_processor.dart';

/// Main class that handles translation resolution with FlutterLocalisation overrides.
///
/// This class is designed to be short-lived, created by `context.tr` when needed.
/// It contains an internal cache for the ICUMessageProcessor to improve performance.
class Translator {
  final BuildContext context;
  final TranslationService service;
  final dynamic generatedLocalizations;

  ICUMessageProcessor? _cachedProcessor;

  Translator({
    required this.context,
    required this.service,
    required this.generatedLocalizations,
  });

  /// The core translation method.
  ///
  /// It first checks the FlutterLocalisation for an override. If one exists,
  /// it is rendered by the ICU processor with the same rules gen-l10n uses.
  /// Otherwise, or when the override cannot be rendered, it falls back to the
  /// standard generated translation.
  ///
  /// [placeholders] is the ARB `placeholders` metadata of the message, which
  /// the generated methods pass so dates and numbers in an override get the
  /// same formatting as the bundled string. [useEscaping] is the project's
  /// `use-escaping` setting, also passed by the generated methods.
  String translate(
    final String key,
    final Map<String, dynamic> arguments,
    final String Function() fallbackGenerator, {
    final Map<String, dynamic>? placeholders,
    final bool useEscaping = false,
  }) {
    final Locale locale = Localizations.localeOf(context);
    final String? overrideTemplate = _overrideFor(locale, key);

    if (overrideTemplate == null) return fallbackGenerator();

    try {
      return _processorFor(locale).format(
        overrideTemplate,
        arguments,
        placeholders: placeholders,
        useEscaping: useEscaping,
      );
    } on Object catch (e) {
      // A malformed override must not reach the screen as raw ICU.
      _log('Could not render the override for "$key", using the bundled '
          'string: $e');
      try {
        return fallbackGenerator();
      } on Object catch (_) {
        return _basicPlaceholderReplacement(overrideTemplate, arguments);
      }
    }
  }

  /// The override for [key], resolved from the most specific locale the cache
  /// actually holds — `pt-BR` before `pt`, `zh-Hant` before `zh`.
  String? _overrideFor(final Locale locale, final String key) {
    for (final String candidate in localeCacheKeys(locale)) {
      final String? template = service.getOverride(candidate, key);
      if (template != null) return template;
    }
    return null;
  }

  ICUMessageProcessor _processorFor(final Locale locale) {
    final ICUMessageProcessor? cached = _cachedProcessor;
    if (cached != null && cached.locale == locale) return cached;
    _log('Created ICUMessageProcessor for ${locale.toLanguageTag()}');
    return _cachedProcessor = ICUMessageProcessor(
      locale,
      const <String, String>{},
      const <String, dynamic>{},
      localeName: _generatedLocaleName(),
    );
  }

  /// gen-l10n formats with its own `localeName`; using the same one keeps
  /// plural rules and number symbols identical to the bundled strings.
  String? _generatedLocaleName() {
    try {
      // ignore: avoid_dynamic_calls
      final Object? name = generatedLocalizations?.localeName;
      return name is String ? name : null;
    } on Object catch (_) {
      return null;
    }
  }

  /// A simple fallback for placeholder replacement if ICU fails.
  String _basicPlaceholderReplacement(
    final String template,
    final Map<String, dynamic> args,
  ) {
    String result = template;
    args.forEach((final String key, final dynamic value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }

  void _log(final String message) {
    if (service.isLoggingEnabled) {
      print('[Translator] $message');
    }
  }

  Future<void> refresh() async {
    await service.refresh();
  }

  Map<String, int> get cacheStatus => service.getCacheStatus();
}
