import 'package:flutter/widgets.dart';
import 'package:flutter_localisation/flutter_localisation.dart';

/// Provider that makes the TranslationService available throughout the widget tree.
///
/// Dependents rebuild when [service] applies a live update.
class TranslationProvider extends InheritedNotifier<TranslationService> {
  /// The translation service instance
  TranslationService get service => notifier!;

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
    required final TranslationService service,
    required this.generatedLocalizations,
    required super.child,
    super.key,
  }) : super(notifier: service);

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
  bool updateShouldNotify(
    covariant final TranslationProvider oldWidget,
  ) {
    return super.updateShouldNotify(oldWidget) ||
        generatedLocalizations != oldWidget.generatedLocalizations;
  }
}
