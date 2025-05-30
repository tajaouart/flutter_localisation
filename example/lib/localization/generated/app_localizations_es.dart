// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'USA App';

  @override
  String hello(Object name) {
    return '¡Hola $name!';
  }

  @override
  String welcomeMessage(Object username) {
    return '¡Bienvenido de vuelta, $username!';
  }

  @override
  String get simpleGreeting => '¡Buenos días!';

  @override
  String itemsInCart(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos',
      one: '1 artículo',
      zero: 'Sin artículos',
    );
    return '$_temp0';
  }

  @override
  String get refresh => 'Actualizar Traducciones';
}
