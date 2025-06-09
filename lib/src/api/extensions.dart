import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';

/// Extension that adds convenient accessors to the BuildContext.
extension SaaSTranslationExtension on BuildContext {
  /// Access the main translator for handling SaaS-enhanced localizations.
  /// Usage: `context.tr.translate('my_key', ...)`
  Translator get tr {
    final provider = TranslationProvider.of(this);
    return Translator(
      context: this,
      service: provider.service,
      generatedLocalizations: provider.generatedLocalizations,
    );
  }

  /// Access the SaaS translation service directly for actions like refreshing.
  /// Usage: `context.translations?.refreshTranslations('en')`
  TranslationService? get translations {
    return TranslationProvider.maybeOf(this)?.service;
  }
}
