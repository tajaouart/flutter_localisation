// lib/src/provider.dart
import 'package:flutter/widgets.dart';

import 'icu_message_processor.dart';
import 'service.dart';

/// Provider that makes SaaS translations available throughout the widget tree
class SaaSTranslationProvider extends InheritedWidget {
  final SaaSTranslationService service;
  final dynamic generatedLocalizations;

  const SaaSTranslationProvider({
    super.key,
    required this.service,
    required this.generatedLocalizations,
    required super.child,
  });

  /// Get the SaaS translation instance from context
  static SaaSTranslationProvider of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<SaaSTranslationProvider>();
    assert(
        result != null,
        'SaaSTranslationProvider not found in widget tree. '
        'Make sure to wrap your app with SaaSTranslationProvider.');
    return result!;
  }

  /// Try to get the SaaS translation instance (returns null if not found)
  static SaaSTranslationProvider? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SaaSTranslationProvider>();
  }

  @override
  bool updateShouldNotify(SaaSTranslationProvider oldWidget) {
    return service != oldWidget.service ||
        generatedLocalizations != oldWidget.generatedLocalizations;
  }
}

/// Extension that adds `.tr` to BuildContext for easy access
extension SaaSTranslationExtension on BuildContext {
  /// Access SaaS-enhanced localizations
  SaaSTranslations get tr {
    final provider = SaaSTranslationProvider.of(this);
    return SaaSTranslations._(
      context: this,
      service: provider.service,
      generatedLocalizations: provider.generatedLocalizations,
    );
  }
}

/// Extension for easy access to the service itself
extension SaaSTranslationServiceExtension on BuildContext {
  /// Access the SaaS translation service directly
  SaaSTranslationService? get saasTranslations {
    return SaaSTranslationProvider.maybeOf(this)?.service;
  }
}

/// Main class that handles translation resolution with SaaS overrides
class SaaSTranslations {
  final BuildContext context;
  final SaaSTranslationService service;
  final dynamic generatedLocalizations;

  const SaaSTranslations._({
    required this.context,
    required this.service,
    required this.generatedLocalizations,
  });

  /// Core translation method that checks SaaS overrides first
  String translate(
    String key,
    Map<String, dynamic> arguments,
    String Function() fallbackGenerator,
  ) {
    final locale = Localizations.localeOf(context);
    final override = service.getOverride(locale.languageCode, key);

    if (override != null) {
      return _processOverride(key, override, arguments);
    }

    return fallbackGenerator();
  }

  /// Process SaaS override using ICUMessageProcessor directly
  String _processOverride(
      String key, String template, Map<String, dynamic> args) {
    try {
      debugPrint('[SaaSTranslations] Processing override for $key');

      // Create ICUMessageProcessor directly with current locale
      final locale = Localizations.localeOf(context);

      // Create processor with just the SaaS override
      final processor = ICUMessageProcessor(
        locale,
        {key: template}, // Only the override
        {}, // Empty metadata for now - can be enhanced later
      );

      debugPrint('[SaaSTranslations] Using ICUMessageProcessor.getString()');

      // Use ICUMessageProcessor's getString - it handles EVERYTHING
      final result = processor.getString(key, args);

      debugPrint('[SaaSTranslations] ICUMessageProcessor success');
      return result;
    } catch (error) {
      debugPrint('[SaaSTranslations] Error: $error');
      return _basicPlaceholderReplacement(template, args);
    }
  }

  /// Minimal fallback for when ICUMessageProcessor is not available
  String _basicPlaceholderReplacement(
      String template, Map<String, dynamic> args) {
    String result = template;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }

  /// Convenience method to refresh translations
  Future<void> refreshTranslations() async {
    final locale = Localizations.localeOf(context);
    await service.refreshTranslations(locale.languageCode);
  }

  /// Get cache status for debugging
  Map<String, int> get cacheStatus => service.getCacheStatus();
}
