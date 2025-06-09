// lib/src/provider.dart
import 'package:flutter/widgets.dart';

import 'service.dart';

/// Provider that makes the TranslationService available throughout the widget tree.
class TranslationProvider extends InheritedWidget {
  final TranslationService service;
  final dynamic generatedLocalizations;

  const TranslationProvider({
    super.key,
    required this.service,
    required this.generatedLocalizations,
    required super.child,
  });

  static TranslationProvider of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<TranslationProvider>();
    assert(result != null, 'TranslationProvider not found in widget tree.');
    return result!;
  }

  static TranslationProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TranslationProvider>();
  }

  @override
  bool updateShouldNotify(TranslationProvider oldWidget) {
    // Rebuild widgets that depend on this provider if the service or localizations change.
    return service != oldWidget.service ||
        generatedLocalizations != oldWidget.generatedLocalizations;
  }
}
