/// Flutter Localisation - A complete localization solution for Flutter apps
///
/// This package provides:
/// - Type-safe localization with auto-generated code
/// - Live translation updates without app releases (paid feature)
/// - Flavor-based localization for multi-environment apps
/// - ICU message format support (plurals, select, gender, etc.)
/// - Web dashboard for managing translations
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_localisation/flutter_localisation.dart';
///
/// void main() {
///   final translationService = TranslationService(
///     config: TranslationConfig.freeUser(),
///   );
///
///   runApp(MyApp(translationService: translationService));
/// }
/// ```
///
/// See https://pub.dev/packages/flutter_localisation for full documentation.
library;

export 'src/api/extensions.dart';
export 'src/api/translator.dart';
export 'src/config.dart';
export 'src/provider.dart';
export 'src/service.dart';
