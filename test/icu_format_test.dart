import 'package:flutter/widgets.dart';
import 'package:flutter_localisation/src/icu_message_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  ICUMessageProcessor processor(final String locale) => ICUMessageProcessor(
        Locale(locale),
        const <String, String>{},
        const <String, dynamic>{},
      );

  group('ICUMessageProcessor.format', () {
    test('nests a plural inside a select', () {
      const String template = '{gender, select, '
          'male{{count, plural, =0{He has none} =1{He has one} other{He has {count}}}} '
          'other{{count, plural, =0{None} other{{count} in total}}}}';
      final ICUMessageProcessor en = processor('en');
      expect(
        en.format(template, <String, dynamic>{'gender': 'male', 'count': 1}),
        'He has one',
      );
      expect(
        en.format(template, <String, dynamic>{'gender': 'male', 'count': 4}),
        'He has 4',
      );
      expect(
        en.format(template, <String, dynamic>{'gender': 'x', 'count': 0}),
        'None',
      );
    });

    test('accepts any spacing around the ICU keywords', () {
      expect(
        processor('en').format(
          '{count,plural,=1{one}other{{count} many}}',
          <String, dynamic>{'count': 2},
        ),
        '2 many',
      );
      expect(
        processor('en').format(
          '{ g ,  select , a {A} other {O} }',
          <String, dynamic>{'g': 'a'},
        ),
        'A',
      );
    });

    test('uses every CLDR category for Arabic', () {
      const String template = '{n, plural, zero{zero} one{one} two{two} '
          'few{few} many{many} other{other}}';
      final ICUMessageProcessor ar = processor('ar');
      String pick(final num n) =>
          ar.format(template, <String, dynamic>{'n': n});
      expect(
        <String>[pick(0), pick(1), pick(2), pick(3), pick(11), pick(100)],
        <String>['zero', 'one', 'two', 'few', 'many', 'other'],
      );
    });

    test('uses few and many for Polish', () {
      const String template =
          '{n, plural, one{one} few{few} many{many} other{other}}';
      final ICUMessageProcessor pl = processor('pl');
      String pick(final num n) =>
          pl.format(template, <String, dynamic>{'n': n});
      expect(
        <String>[pick(1), pick(3), pick(5), pick(22)],
        <String>['one', 'few', 'many', 'few'],
      );
    });

    test('prefers an exact match over the category', () {
      expect(
        processor('en').format(
          '{n, plural, =5{five exactly} other{{n} items}}',
          <String, dynamic>{'n': 5},
        ),
        'five exactly',
      );
    });

    test('takes a double count without throwing', () {
      expect(
        processor('en').format(
          '{n, plural, =1{one} other{{n} items}}',
          <String, dynamic>{'n': 2.5},
        ),
        '2.5 items',
      );
    });

    test('keeps apostrophes and stray braces as text', () {
      expect(
        processor('fr').format(
          "Il n'a {n} ami {pas}",
          <String, dynamic>{'n': 1, 'pas': 'x'},
        ),
        "Il n'a 1 ami x",
      );
      expect(
        processor('en').format('a } b { c', <String, dynamic>{}),
        'a } b { c',
      );
    });

    test('rejects a plural without other and an unclosed case', () {
      expect(
        () => processor('en').format(
          '{n, plural, =1{one}}',
          <String, dynamic>{'n': 3},
        ),
        throwsFormatException,
      );
      expect(
        () => processor('en')
            .format('{n, plural, =1{one', <String, dynamic>{'n': 1}),
        throwsFormatException,
      );
    });

    test('formats dates like gen-l10n', () {
      final DateTime date = DateTime(2026, 1, 5, 9, 30);
      final ICUMessageProcessor en = processor('en');
      String render(final Map<String, dynamic> meta) => en.format(
            '{d}',
            <String, dynamic>{'d': date},
            placeholders: <String, dynamic>{'d': meta},
          );
      expect(
        render(<String, dynamic>{'type': 'DateTime', 'format': 'yMMMMd'}),
        'January 5, 2026',
      );
      expect(
        render(<String, dynamic>{'type': 'DateTime', 'format': 'MMMEd+jm'}),
        'Mon, Jan 5 9:30 AM',
      );
      expect(
        render(<String, dynamic>{
          'type': 'DateTime',
          'format': 'dd/MM',
          'isCustomDateFormat': 'true',
        }),
        '05/01',
      );
    });

    test('formats numbers like gen-l10n', () {
      final ICUMessageProcessor en = processor('en');
      String render(final num value, final Map<String, dynamic> meta) =>
          en.format(
            '{v}',
            <String, dynamic>{'v': value},
            placeholders: <String, dynamic>{'v': meta},
          );
      expect(render(1500000, <String, dynamic>{'format': 'compact'}), '1.5M');
      expect(
        render(1234.5, <String, dynamic>{
          'format': 'simpleCurrency',
          'optionalParameters': <String, dynamic>{'name': 'USD'},
        }),
        r'$1,234.50',
      );
      expect(
        render(0.875, <String, dynamic>{'format': 'percentPattern'}),
        '88%',
      );
      expect(
        render(0.875, <String, dynamic>{
          'format': 'decimalPercentPattern',
          'optionalParameters': <String, dynamic>{'decimalDigits': 1},
        }),
        '87.5%',
      );
      expect(render(42, <String, dynamic>{'type': 'int'}), '42');
    });

    test('reads ARB quoting when the project uses use-escaping', () {
      final ICUMessageProcessor en = processor('en');
      expect(
        en.format(
          "It''s '{name}' for {name}",
          <String, dynamic>{'name': 'Sam'},
          useEscaping: true,
        ),
        "It's {name} for Sam",
      );
      expect(
        en.format("It''s {name}", <String, dynamic>{'name': 'Sam'}),
        "It''s Sam",
      );
      expect(
        () => en.format(
          "an 'open quote",
          <String, dynamic>{},
          useEscaping: true,
        ),
        throwsFormatException,
      );
    });
  });
}
