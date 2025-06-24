import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';

/// Extension that adds convenient accessors to the BuildContext.
extension FlutterLocalisationExtension on BuildContext {
  /// Access the main translator for handling enhanced localizations.
  /// Usage: `context.tr.translate('my_key', ...)`
  Translator get tr {
    final TranslationProvider provider = TranslationProvider.of(this);
    return Translator(
      context: this,
      service: provider.service,
      generatedLocalizations: provider.generatedLocalizations,
    );
  }

  /// Access the FlutterLocalisation translation service directly for actions like refreshing.
  /// Usage: `context.translations?.refreshTranslations('en')`
  TranslationService? get translations {
    return TranslationProvider.maybeOf(this)?.service;
  }
}
