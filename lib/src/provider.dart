import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';

/// Provider that makes the TranslationService available throughout the widget tree.
class TranslationProvider extends InheritedWidget {
  /// The translation service instance
  final TranslationService service;

  /// The generated Flutter localizations (AppLocalizations)
  final dynamic generatedLocalizations;

  /// Creates a translation provider that exposes translation services to descendants
  ///
  /// Example:
  /// ```dart
  /// TranslationProvider(
  ///   service: translationService,
  ///   generatedLocalizations: AppLocalizations.of(context),
  ///   child: MyApp(),
  /// )
  /// ```
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

  /// Returns the [TranslationProvider] from the widget tree, or null if not found
  ///
  /// Unlike [of], this method returns null instead of throwing an error when
  /// no provider is found in the widget tree.
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
