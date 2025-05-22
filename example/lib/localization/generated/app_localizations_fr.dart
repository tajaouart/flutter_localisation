// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Mexico App';

  @override
  String get title => 'Démonstration de la localisation Flutter';

  @override
  String greeting(Object name) {
    return 'Bonjour $name, bienvenue!';
  }

  @override
  String hello_world(Object name, Object count, Object categories) {
    return 'Bonjour $name, vous avez $count articles dans $categories catégories.';
  }

  @override
  String get thankYou => 'Merci d\'utiliser notre application!';

  @override
  String get goodbyeMessage => 'Au revoir! Passez une bonne journée!';
}
