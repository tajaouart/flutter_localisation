// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Mexico App';

  @override
  String get title => 'Demostración de localización de Flutter';

  @override
  String greeting(Object name) {
    return 'Hola $name, bienvenido!';
  }

  @override
  String hello_world(Object name, Object count, Object categories) {
    return 'Hola $name, tienes $count artículos en $categories categorías.';
  }

  @override
  String get thankYou => '¡Gracias por usar nuestra aplicación!';

  @override
  String get goodbyeMessage => '¡Adiós! ¡Que tengas un gran día!';
}
