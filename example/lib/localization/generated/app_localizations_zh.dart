// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'USA App';

  @override
  String get simpleGreeting => '早上好！';

  @override
  String hello(String name) {
    return '你好，$name！';
  }

  @override
  String welcomeMessage(String username) {
    return '欢迎回来，$username！';
  }

  @override
  String itemsInCart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件商品',
      zero: '购物车是空的',
    );
    return '$_temp0';
  }

  @override
  String notificationFrom(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': '他给你发了一条消息',
      'female': '她给你发了一条消息',
      'other': '对方给你发了一条消息',
    });
    return '$_temp0';
  }

  @override
  String friendsInvited(String gender, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他邀请了 $count 位朋友',
      zero: '他还没有邀请任何人',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '她邀请了 $count 位朋友',
      zero: '她还没有邀请任何人',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '邀请了 $count 位朋友',
      zero: '还没有邀请任何人',
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

    return '最后上线：$dateString';
  }

  @override
  String eventStarts(DateTime when) {
    final intl.DateFormat whenDateFormat = intl.DateFormat.MMMEd(localeName)
        .add_jm();
    final String whenString = whenDateFormat.format(when);

    return '开始时间：$whenString';
  }

  @override
  String orderTotal(double amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return '合计：$amountString';
  }

  @override
  String downloads(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '下载量：$countString';
  }

  @override
  String progress(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '已完成 $valueString';
  }

  @override
  String get refreshTranslations => '刷新翻译';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'USA App';

  @override
  String get simpleGreeting => '早安！';

  @override
  String hello(String name) {
    return '你好，$name！';
  }

  @override
  String welcomeMessage(String username) {
    return '歡迎回來，$username！';
  }

  @override
  String itemsInCart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件商品',
      zero: '購物車是空的',
    );
    return '$_temp0';
  }

  @override
  String notificationFrom(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': '他給你傳了一則訊息',
      'female': '她給你傳了一則訊息',
      'other': '對方給你傳了一則訊息',
    });
    return '$_temp0';
  }

  @override
  String friendsInvited(String gender, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他邀請了 $count 位朋友',
      zero: '他還沒有邀請任何人',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '她邀請了 $count 位朋友',
      zero: '她還沒有邀請任何人',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '邀請了 $count 位朋友',
      zero: '還沒有邀請任何人',
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

    return '最後上線：$dateString';
  }

  @override
  String eventStarts(DateTime when) {
    final intl.DateFormat whenDateFormat = intl.DateFormat.MMMEd(localeName)
        .add_jm();
    final String whenString = whenDateFormat.format(when);

    return '開始時間：$whenString';
  }

  @override
  String orderTotal(double amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return '合計：$amountString';
  }

  @override
  String downloads(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '下載量：$countString';
  }

  @override
  String progress(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '已完成 $valueString';
  }

  @override
  String get refreshTranslations => '重新整理翻譯';
}
