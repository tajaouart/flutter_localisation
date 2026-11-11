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
  String get simpleGreeting => 'Good morning!';

  @override
  String hello(String name) {
    return 'Hello $name!';
  }

  @override
  String welcomeMessage(String username) {
    return 'Welcome back, $username!';
  }

  @override
  String itemsInCart(int count) {
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
  String notificationFrom(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': 'He sent you a message',
      'female': 'She sent you a message',
      'other': 'They sent you a message',
    });
    return '$_temp0';
  }

  @override
  String friendsInvited(String gender, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'He invited $count friends',
      one: 'He invited one friend',
      zero: 'He has not invited anyone yet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'She invited $count friends',
      one: 'She invited one friend',
      zero: 'She has not invited anyone yet',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They invited $count friends',
      one: 'They invited one friend',
      zero: 'They have not invited anyone yet',
    );
    String _temp3 = intl.Intl.selectLogic(gender, {
      'male': '$_temp0',
      'female': '$_temp1',
      'other': '$_temp2',
    });
    return '$_temp3';
  }

  @override
  String lastSeen(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Last seen $dateString';
  }

  @override
  String eventStarts(DateTime when) {
    final intl.DateFormat whenDateFormat = intl.DateFormat.MMMEd(localeName)
        .add_jm();
    final String whenString = whenDateFormat.format(when);

    return 'Starts $whenString';
  }

  @override
  String orderTotal(double amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return 'Total: $amountString';
  }

  @override
  String downloads(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return 'Downloads: $countString';
  }

  @override
  String progress(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString complete';
  }

  @override
  String get refreshTranslations => 'Refresh translations';
}
