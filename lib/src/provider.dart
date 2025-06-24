import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';

/// Provider that makes the TranslationService available throughout the widget tree.
class TranslationProvider extends InheritedWidget {
  final TranslationService service;
  final dynamic generatedLocalizations;

  const TranslationProvider({
    required this.service,
    required this.generatedLocalizations,
    required super.child,
    super.key,
  });

  static TranslationProvider of(final BuildContext context) {
    final TranslationProvider? result =
        context.dependOnInheritedWidgetOfExactType<TranslationProvider>();
    assert(result != null, 'TranslationProvider not found in widget tree.');
    return result!;
  }

  static TranslationProvider? maybeOf(final BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TranslationProvider>();
  }

  @override
  bool updateShouldNotify(final TranslationProvider oldWidget) {
    // Rebuild widgets that depend on this provider if the service or localizations change.
    return service != oldWidget.service ||
        generatedLocalizations != oldWidget.generatedLocalizations;
  }
}
