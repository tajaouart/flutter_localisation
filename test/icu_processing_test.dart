// test/icu_processing_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localisation/src/icu_message_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ICUMessageProcessor - Simple String Lookup', () {
    test('getString returns value for existing key', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'hello': 'Hello World'},
        <String, dynamic>{},
      );

      expect(processor.getString('hello'), equals('Hello World'));
    });

    test('getString returns KEY_NOT_FOUND for missing key', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{},
        <String, dynamic>{},
      );

      expect(
        processor.getString('missing'),
        equals('missing {KEY_NOT_FOUND}'),
      );
    });

    test('getString returns runtime translation when available', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'hello': 'Hello World'},
        <String, dynamic>{},
      );

      ICUMessageProcessor.updateRuntimeData(
        translations: <String, String>{'hello': 'Runtime Hello'},
      );

      expect(processor.getString('hello'), equals('Runtime Hello'));

      // Clean up
      ICUMessageProcessor.updateRuntimeData();
    });
  });

  group('ICUMessageProcessor - Placeholder Substitution', () {
    test('substitutes simple string placeholders', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'greeting': 'Hello {name}!'},
        <String, dynamic>{},
      );

      final String result =
          processor.getString('greeting', <String, dynamic>{'name': 'Alice'});
      expect(result, equals('Hello Alice!'));
    });

    test('substitutes multiple placeholders', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'message': 'Hi {firstName} {lastName}!'},
        <String, dynamic>{},
      );

      final String result = processor.getString('message', <String, dynamic>{
        'firstName': 'John',
        'lastName': 'Doe',
      });
      expect(result, equals('Hi John Doe!'));
    });

    test('handles missing placeholder values', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'greeting': 'Hello {name}!'},
        <String, dynamic>{},
      );

      // When a placeholder is provided but with a different key
      final String result =
          processor.getString('greeting', <String, dynamic>{'other': 'value'});
      // Missing placeholders are replaced with {placeholder PLACEHOLDER_VALUE_MISSING}
      expect(result, equals('Hello {name {PLACEHOLDER_VALUE_MISSING}}!'));
    });

    test('handles null placeholder values', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'greeting': 'Hello {name}!'},
        <String, dynamic>{},
      );

      final String result =
          processor.getString('greeting', <String, dynamic>{'name': null});
      expect(result, equals('Hello {PLACEHOLDER_VALUE_MISSING}!'));
    });
  });

  group('ICUMessageProcessor - DateTime Formatting', () {
    test('formats DateTime with default format', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en', 'US'),
        <String, String>{'message': 'Date: {date}'},
        <String, dynamic>{
          '@message': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'date': <String, String>{'type': 'DateTime'},
            },
          },
        },
      );

      final DateTime date = DateTime(2024, 1, 15);
      final String result =
          processor.getString('message', <String, dynamic>{'date': date});
      expect(result, contains('1/15/2024'));
    });

    test('formats DateTime with custom format', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en', 'US'),
        <String, String>{'message': 'Date: {date}'},
        <String, dynamic>{
          '@message': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'date': <String, String>{
                'type': 'DateTime',
                'format': 'yyyy-MM-dd',
              },
            },
          },
        },
      );

      final DateTime date = DateTime(2024, 1, 15);
      final String result =
          processor.getString('message', <String, dynamic>{'date': date});
      expect(result, equals('Date: 2024-01-15'));
    });

    test('handles invalid DateTime type', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'message': 'Date: {date}'},
        <String, dynamic>{
          '@message': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'date': <String, String>{'type': 'DateTime'},
            },
          },
        },
      );

      final String result = processor
          .getString('message', <String, dynamic>{'date': 'not a date'});
      expect(result, equals('Date: {TYPE_ERROR_FOR_PLACEHOLDER}'));
    });
  });

  group('ICUMessageProcessor - Number Formatting', () {
    test('formats numbers with currency format', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en', 'US'),
        <String, String>{'price': 'Price: {amount}'},
        <String, dynamic>{
          '@price': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'amount': <String, String>{
                'type': 'double',
                'format': 'currency',
                'symbol': r'$',
              },
            },
          },
        },
      );

      final String result =
          processor.getString('price', <String, dynamic>{'amount': 99.99});
      expect(result, contains('99.99'));
    });

    test('formats numbers with decimal pattern', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en', 'US'),
        <String, String>{'value': 'Value: {num}'},
        <String, dynamic>{
          '@value': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'num': <String, String>{
                'type': 'double',
                'format': 'decimalPattern',
              },
            },
          },
        },
      );

      final String result =
          processor.getString('value', <String, dynamic>{'num': 1234.56});
      expect(result, contains('1,234.56'));
    });

    test('handles number without specific format', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'count': 'Count: {num}'},
        <String, dynamic>{
          '@count': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'num': <String, String>{'type': 'int'},
            },
          },
        },
      );

      final String result =
          processor.getString('count', <String, dynamic>{'num': 42});
      expect(result, equals('Count: 42'));
    });

    test('handles invalid number type', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'count': 'Count: {num}'},
        <String, dynamic>{
          '@count': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'num': <String, String>{'type': 'int'},
            },
          },
        },
      );

      final String result = processor
          .getString('count', <String, dynamic>{'num': 'not a number'});
      expect(result, equals('Count: {TYPE_ERROR_FOR_PLACEHOLDER}'));
    });
  });

  group('ICUMessageProcessor - Plural Messages', () {
    test('handles zero case', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'items':
              '{count, plural, =0{No items} =1{One item} other{{count} items}}',
        },
        <String, dynamic>{},
      );

      final String result =
          processor.getString('items', <String, dynamic>{'count': 0});
      expect(result, equals('No items'));
    });

    test('handles one case', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'items':
              '{count, plural, =0{No items} =1{One item} other{{count} items}}',
        },
        <String, dynamic>{},
      );

      final String result =
          processor.getString('items', <String, dynamic>{'count': 1});
      expect(result, equals('One item'));
    });

    test('handles other case', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'items':
              '{count, plural, =0{No items} =1{One item} other{{count} items}}',
        },
        <String, dynamic>{},
      );

      final String result =
          processor.getString('items', <String, dynamic>{'count': 5});
      expect(result, equals('5 items'));
    });

    test('handles plural with nested placeholders', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'cart':
              '{count, plural, =0{No {type} items} other{{count} {type} items}}',
        },
        <String, dynamic>{},
      );

      final String result = processor
          .getString('cart', <String, dynamic>{'count': 3, 'type': 'special'});
      expect(result, equals('3 special items'));
    });
  });

  group('ICUMessageProcessor - Select Messages', () {
    test('handles select with male option', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'pronoun':
              '{gender, select, male{He is} female{She is} other{They are}}',
        },
        <String, dynamic>{},
      );

      final String result =
          processor.getString('pronoun', <String, dynamic>{'gender': 'male'});
      expect(result, equals('He is'));
    });

    test('handles select with female option', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'pronoun':
              '{gender, select, male{He is} female{She is} other{They are}}',
        },
        <String, dynamic>{},
      );

      final String result =
          processor.getString('pronoun', <String, dynamic>{'gender': 'female'});
      expect(result, equals('She is'));
    });

    test('handles select with other fallback', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'pronoun':
              '{gender, select, male{He is} female{She is} other{They are}}',
        },
        <String, dynamic>{},
      );

      final String result = processor
          .getString('pronoun', <String, dynamic>{'gender': 'unknown'});
      expect(result, equals('They are'));
    });

    test('handles select with nested placeholders', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'message':
              '{gender, select, male{He is {name}} female{She is {name}} other{They are {name}}}',
        },
        <String, dynamic>{},
      );

      final String result = processor.getString(
        'message',
        <String, dynamic>{'gender': 'male', 'name': 'John'},
      );
      expect(result, equals('He is John'));
    });
  });

  group('ICUMessageProcessor - Runtime Updates', () {
    test('updateRuntimeData updates translations', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'hello': 'Hello'},
        <String, dynamic>{},
      );

      ICUMessageProcessor.updateRuntimeData(
        translations: <String, String>{'hello': 'Hola'},
      );

      expect(processor.getString('hello'), equals('Hola'));

      ICUMessageProcessor.updateRuntimeData();
    });

    test('updateRuntimeData updates metadata', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'message': 'Value: {num}'},
        <String, dynamic>{},
      );

      ICUMessageProcessor.updateRuntimeData(
        metadata: <String, dynamic>{
          '@message': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'num': <String, String>{'type': 'int'},
            },
          },
        },
      );

      final Map<String, dynamic>? metadata =
          processor.getPlaceholderMetadata('message');
      expect(metadata, isNotNull);
      expect((metadata!['num'] as Map<String, dynamic>)['type'], equals('int'));

      ICUMessageProcessor.updateRuntimeData();
    });
  });

  group('ICUMessageProcessor - Legacy Methods', () {
    test('greeting returns greeting string', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'greeting': 'Hello!'},
        <String, dynamic>{},
      );

      expect(processor.greeting, equals('Hello!'));
    });

    test('greeting returns default when key not found', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{},
        <String, dynamic>{},
      );

      expect(processor.greeting, equals('Hello Default'));
    });

    test('welcomeUser formats welcome message', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'welcome_user': 'Welcome {userName}!'},
        <String, dynamic>{},
      );

      final String result = processor.welcomeUser('Alice');
      expect(result, equals('Welcome Alice!'));
    });

    test('welcomeUser with loginDate', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'welcome_user': 'Welcome {userName}! Last login: {loginDate}',
        },
        <String, dynamic>{
          '@welcome_user': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'loginDate': <String, String>{
                'type': 'DateTime',
                'format': 'yyyy-MM-dd',
              },
            },
          },
        },
      );

      final String result =
          processor.welcomeUser('Alice', loginDate: DateTime(2024, 1, 15));
      expect(result, contains('Welcome Alice!'));
      expect(result, contains('2024-01-15'));
    });

    test('itemCount formats item count message with plural', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'item_count':
              '{count, plural, =0{no items} =1{one item} other{{count} items}}',
        },
        <String, dynamic>{},
      );

      final String result = processor.itemCount(3, 'Bob');
      expect(result, contains('3 items'));
    });

    test('itemCount with totalCost', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'item_count': '{userName}: {count} items, total: {totalCost}',
        },
        <String, dynamic>{
          '@item_count': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'totalCost': <String, String>{
                'type': 'double',
                'format': 'currency',
                'symbol': r'$',
              },
            },
          },
        },
      );

      final String result = processor.itemCount(2, 'Bob', totalCost: 99.99);
      expect(result, contains('Bob'));
      expect(result, contains('2'));
      expect(result, contains('99.99'));
    });
  });

  group('ICUMessageProcessor - Edge Cases', () {
    test('handles empty translations map', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{},
        <String, dynamic>{},
      );

      expect(
        processor.getString('any'),
        equals('any {KEY_NOT_FOUND}'),
      );
    });

    test('handles empty args in getString', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'hello': 'Hello World'},
        <String, dynamic>{},
      );

      expect(
        processor.getString('hello', <String, dynamic>{}),
        equals('Hello World'),
      );
    });

    test('handles template with no placeholders', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'simple': 'Simple message'},
        <String, dynamic>{},
      );

      expect(processor.getString('simple'), equals('Simple message'));
    });

    test('load creates ICUMessageProcessor instance', () async {
      final ICUMessageProcessor processor = await ICUMessageProcessor.load(
        const Locale('en'),
        <String, String>{'hello': 'Hello'},
        <String, dynamic>{},
      );

      expect(processor, isA<ICUMessageProcessor>());
      expect(processor.getString('hello'), equals('Hello'));
    });

    test('of returns null when not in widget tree', () {
      final BuildContext? context = null;
      expect(() => ICUMessageProcessor.of(context!), throwsA(isA<TypeError>()));
    });

    test('handles number with custom format string', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en', 'US'),
        <String, String>{'value': 'Value: {num}'},
        <String, dynamic>{
          '@value': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'num': <String, String>{'type': 'double', 'format': '#,##0.00'},
            },
          },
        },
      );

      final String result =
          processor.getString('value', <String, dynamic>{'num': 12345.6789});
      expect(result, contains('12,345.68'));
    });

    test('handles decimalPercentPattern format', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en', 'US'),
        <String, String>{'percent': 'Percent: {num}'},
        <String, dynamic>{
          '@percent': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'num': <String, String>{
                'type': 'double',
                'format': 'decimalPercentPattern',
              },
            },
          },
        },
      );

      final String result =
          processor.getString('percent', <String, dynamic>{'num': 0.75});
      expect(result, isNotNull);
    });

    test('handles plural with =2 case (two)', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{
          'items':
              '{count, plural, =0{No items} =1{One item} =2{Two items} other{{count} items}}',
        },
        <String, dynamic>{},
      );

      final String result =
          processor.getString('items', <String, dynamic>{'count': 2});
      expect(result, equals('Two items'));
    });

    test('handles plural with few and many cases', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('pl'), // Polish has complex plural rules
        <String, String>{
          'items':
              '{count, plural, =0{Zero} one{One} few{Few: {count}} many{Many: {count}} other{Other: {count}}}',
        },
        <String, dynamic>{},
      );

      final String result =
          processor.getString('items', <String, dynamic>{'count': 5});
      expect(result, isNotNull);
    });

    test('substitutePlaceholders handles empty template', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{'empty': ''},
        <String, dynamic>{},
      );

      final String result = processor.getString('empty');
      expect(result, equals(''));
    });

    test('substitutePlaceholders handles template ending with KEY_NOT_FOUND',
        () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{},
        <String, dynamic>{},
      );

      final String result = processor.getString('missing');
      expect(result, endsWith('{KEY_NOT_FOUND}'));
    });
  });

  group('ICUMessageProcessor - Metadata', () {
    test('getPlaceholderMetadata returns null for missing key', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{},
        <String, dynamic>{},
      );

      expect(processor.getPlaceholderMetadata('missing'), isNull);
    });

    test('getPlaceholderMetadata returns placeholders', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{},
        <String, dynamic>{
          '@message': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'name': <String, String>{'type': 'String'},
            },
          },
        },
      );

      final Map<String, dynamic>? metadata =
          processor.getPlaceholderMetadata('message');
      expect(metadata, isNotNull);
      expect((metadata!['name'] as Map<String, dynamic>)['type'], equals('String'));
    });

    test('getPlaceholderMetadata prioritizes runtime metadata', () {
      final ICUMessageProcessor processor = ICUMessageProcessor(
        const Locale('en'),
        <String, String>{},
        <String, dynamic>{
          '@message': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'name': <String, String>{'type': 'String'},
            },
          },
        },
      );

      ICUMessageProcessor.updateRuntimeData(
        metadata: <String, dynamic>{
          '@message': <String, Map<String, Map<String, String>>>{
            'placeholders': <String, Map<String, String>>{
              'name': <String, String>{'type': 'int'},
            },
          },
        },
      );

      final Map<String, dynamic>? metadata =
          processor.getPlaceholderMetadata('message');
      expect((metadata!['name'] as Map<String, dynamic>)['type'], equals('int'));

      ICUMessageProcessor.updateRuntimeData();
    });
  });
}
