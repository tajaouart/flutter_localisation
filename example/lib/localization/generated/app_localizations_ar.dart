// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'USA App';

  @override
  String get simpleGreeting => 'صباح الخير!';

  @override
  String hello(String name) {
    return 'مرحبًا $name!';
  }

  @override
  String welcomeMessage(String username) {
    return 'مرحبًا بعودتك، $username!';
  }

  @override
  String itemsInCart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا توجد عناصر',
    );
    return '$_temp0';
  }

  @override
  String notificationFrom(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': 'أرسل إليك رسالة',
      'female': 'أرسلت إليك رسالة',
      'other': 'أرسلوا إليك رسالة',
    });
    return '$_temp0';
  }

  @override
  String friendsInvited(String gender, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'دعا $count صديق',
      many: 'دعا $count صديقًا',
      few: 'دعا $count أصدقاء',
      two: 'دعا صديقين',
      one: 'دعا صديقًا واحدًا',
      zero: 'لم يدعُ أحدًا بعد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'دعت $count صديق',
      many: 'دعت $count صديقًا',
      few: 'دعت $count أصدقاء',
      two: 'دعت صديقين',
      one: 'دعت صديقًا واحدًا',
      zero: 'لم تدعُ أحدًا بعد',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'دعوا $count صديق',
      many: 'دعوا $count صديقًا',
      few: 'دعوا $count أصدقاء',
      two: 'دعوا صديقين',
      one: 'دعوا صديقًا واحدًا',
      zero: 'لم يدعوا أحدًا بعد',
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

    return 'آخر ظهور $dateString';
  }

  @override
  String eventStarts(DateTime when) {
    final intl.DateFormat whenDateFormat = intl.DateFormat.MMMEd(localeName)
        .add_jm();
    final String whenString = whenDateFormat.format(when);

    return 'يبدأ $whenString';
  }

  @override
  String orderTotal(double amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return 'المجموع: $amountString';
  }

  @override
  String downloads(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return 'التنزيلات: $countString';
  }

  @override
  String progress(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return 'اكتمل $valueString';
  }

  @override
  String get refreshTranslations => 'تحديث الترجمات';
}
