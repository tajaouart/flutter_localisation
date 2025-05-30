// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'USA App';

  @override
  String hello(Object name) {
    return 'Hello $name!';
  }

  @override
  String welcomeMessage(Object username) {
    return 'Welcome back, $username!';
  }

  @override
  String get simpleGreeting => 'Good morning!';

  @override
  String itemsInCart(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get refresh => 'Refresh Translations';
}
