// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'USA App';

  @override
  String get simpleGreeting => 'Bonjour !';

  @override
  String hello(String name) {
    return 'Bonjour $name !';
  }

  @override
  String welcomeMessage(String username) {
    return 'Bon retour, $username !';
  }

  @override
  String itemsInCart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
      zero: 'Aucun article',
    );
    return '$_temp0';
  }

  @override
  String notificationFrom(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': 'Il vous a envoyé un message',
      'female': 'Elle vous a envoyé un message',
      'other': 'Vous avez reçu un message',
    });
    return '$_temp0';
  }

  @override
  String friendsInvited(String gender, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il a invité $count amis',
      one: 'Il a invité un ami',
      zero: 'Il n\'a encore invité personne',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Elle a invité $count amis',
      one: 'Elle a invité une amie',
      zero: 'Elle n\'a encore invité personne',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amis ont été invités',
      one: 'Un ami a été invité',
      zero: 'Personne n\'a encore été invité',
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

    return 'Vu pour la dernière fois le $dateString';
  }

  @override
  String eventStarts(DateTime when) {
    final intl.DateFormat whenDateFormat = intl.DateFormat.MMMEd(localeName)
        .add_jm();
    final String whenString = whenDateFormat.format(when);

    return 'Début : $whenString';
  }

  @override
  String orderTotal(double amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return 'Total : $amountString';
  }

  @override
  String downloads(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return 'Téléchargements : $countString';
  }

  @override
  String progress(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString terminé';
  }

  @override
  String get refreshTranslations => 'Actualiser les traductions';
}
