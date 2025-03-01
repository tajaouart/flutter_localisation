// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Flutter Localization Demo';

  @override
  String greeting(String name) {
    return 'Hello $name, welcome again!';
  }

  @override
  String hello_worl(String name, String count, String categories) {
    return 'Hello $name, you have $count items in $categories categories.';
  }

  @override
  String get thankYou => 'Thank you for using our app!';

  @override
  String get goodbyeMessage => 'Goodbye! Have a great day!';
}
