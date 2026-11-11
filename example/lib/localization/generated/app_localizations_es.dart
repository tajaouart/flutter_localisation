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
  String get simpleGreeting => '¡Buenos días!';

  @override
  String hello(String name) {
    return '¡Hola $name!';
  }

  @override
  String welcomeMessage(String username) {
    return '¡Bienvenido de vuelta, $username!';
  }

  @override
  String itemsInCart(int count) {
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
  String notificationFrom(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': 'Él te envió un mensaje',
      'female': 'Ella te envió un mensaje',
      'other': 'Te enviaron un mensaje',
    });
    return '$_temp0';
  }

  @override
  String friendsInvited(String gender, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Él invitó a $count amigos',
      one: 'Él invitó a un amigo',
      zero: 'Él aún no ha invitado a nadie',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ella invitó a $count amigos',
      one: 'Ella invitó a un amigo',
      zero: 'Ella aún no ha invitado a nadie',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Invitaron a $count amigos',
      one: 'Invitaron a un amigo',
      zero: 'Aún no han invitado a nadie',
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

    return 'Última conexión: $dateString';
  }

  @override
  String eventStarts(DateTime when) {
    final intl.DateFormat whenDateFormat = intl.DateFormat.MMMEd(localeName)
        .add_jm();
    final String whenString = whenDateFormat.format(when);

    return 'Empieza: $whenString';
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

    return 'Descargas: $countString';
  }

  @override
  String progress(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString completado';
  }

  @override
  String get refreshTranslations => 'Actualizar traducciones';
}

/// The translations for Spanish Castilian, as used in Mexico (`es_MX`).
class AppLocalizationsEsMx extends AppLocalizationsEs {
  AppLocalizationsEsMx() : super('es_MX');

  @override
  String get simpleGreeting => '¡Buen día!';

  @override
  String itemsInCart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count productos',
      one: '1 producto',
      zero: 'Sin productos',
    );
    return '$_temp0';
  }
}
