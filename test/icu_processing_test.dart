// test/icu_processing_test.dart
import 'package:test/test.dart';

void main() {
  group('ICU Plural Processing Tests', () {
    test('should handle zero case correctly', () {
      const template =
          '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
      final result = processICUPlural(template, {'count': 0});

      expect(result, equals('🛒 No items'));
    });

    test('should handle one case correctly', () {
      const template =
          '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
      final result = processICUPlural(template, {'count': 1});

      expect(result, equals('🛒 1 item'));
    });

    test('should handle other case correctly', () {
      const template =
          '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
      final result = processICUPlural(template, {'count': 5});

      expect(result, equals('🛒 5 items'));
    });

    test('should handle complex FlutterLocalisation ICU template', () {
      const template =
          '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}';
      final result = processICUPlural(template, {'count': 10});

      expect(result, equals('🛒 FlutterLocalisation: 10 amazing items'));
    });

    test('should handle Spanish FlutterLocalisation ICU template', () {
      const template =
          '{count, plural, =0{🛒 FlutterLocalisation: Sin artículos en carrito} =1{🛒 FlutterLocalisation: 1 artículo increíble} other{🛒 FlutterLocalisation: {count} artículos increíbles}}';
      final result = processICUPlural(template, {'count': 3});

      expect(result, equals('🛒 FlutterLocalisation: 3 artículos increíbles'));
    });

    test('should handle nested placeholders', () {
      const template =
          '{count, plural, =0{No {type} items} =1{1 {type} item} other{{count} {type} items}}';
      final result =
          processICUPlural(template, {'count': 4, 'type': 'special'});

      expect(result, equals('4 special items'));
    });

    test('should handle malformed ICU gracefully', () {
      const template = '{count, plural, broken}';
      final result = processICUPlural(template, {'count': 1});

      expect(result, equals(template)); // Should return original template
    });

    test('should handle missing count parameter', () {
      const template = '{count, plural, =0{No items} other{{count} items}}';
      final result = processICUPlural(template, {});

      expect(result, equals('No items')); // Should default to count = 0
    });

    test('should handle emojis and special characters', () {
      const template =
          '{count, plural, =0{🚫 Empty} =1{⭐ One star} other{⭐ {count} stars}}';
      final result = processICUPlural(template, {'count': 5});

      expect(result, equals('⭐ 5 stars'));
    });

    test('should handle complex spacing in ICU', () {
      const template =
          '{count,plural,=0{No items}=1{One item}other{{count} items}}';
      final result = processICUPlural(template, {'count': 2});

      expect(result, equals('2 items'));
    });
  });

  group('Simple String Replacement Tests', () {
    test('should replace basic placeholders', () {
      const template = 'Hello {name}!';
      final result = processSimpleReplacement(template, {'name': 'World'});

      expect(result, equals('Hello World!'));
    });

    test('should handle multiple placeholders', () {
      const template = 'Welcome {username}, you have {count} messages';
      final result = processSimpleReplacement(template, {
        'username': 'Alice',
        'count': 5,
      });

      expect(result, equals('Welcome Alice, you have 5 messages'));
    });

    test('should handle missing placeholders gracefully', () {
      const template = 'Hello {name}!';
      final result = processSimpleReplacement(template, {});

      expect(result,
          equals('Hello {name}!')); // Should leave placeholder unchanged
    });

    test('should delegate ICU plurals to ICU processor', () {
      const template = '{count, plural, =0{No items} other{{count} items}}';
      final result = processSimpleReplacement(template, {'count': 3});

      expect(result, equals('3 items'));
    });
  });
}

/// Test implementation of ICU plural processing
/// This is a copy of the logic from the provider for testing
String processICUPlural(String template, Map<String, dynamic> args) {
  try {
    final count = args['count'] as int? ?? 0;

    final Map<String, String> cases = {};

    final patterns = {
      'zero': RegExp(r'=0\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'),
      'one': RegExp(r'=1\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'),
      'other': RegExp(r'other\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'),
    };

    patterns.forEach((caseName, pattern) {
      final match = pattern.firstMatch(template);
      if (match != null && match.group(1) != null) {
        cases[caseName] = match.group(1)!;
      }
    });

    String? selectedCase;

    if (count == 0 && cases.containsKey('zero')) {
      selectedCase = cases['zero'];
    } else if (count == 1 && cases.containsKey('one')) {
      selectedCase = cases['one'];
    } else if (cases.containsKey('other')) {
      selectedCase = cases['other'];
    }

    if (selectedCase == null) {
      return template;
    }

    String result = selectedCase;
    for (final entry in args.entries) {
      final placeholder = '{${entry.key}}';
      final value = entry.value.toString();
      result = result.replaceAll(placeholder, value);
    }

    return result;
  } catch (error) {
    return template;
  }
}

/// Test implementation of simple string replacement
String processSimpleReplacement(String template, Map<String, dynamic> args) {
  if (template.contains('plural,')) {
    return processICUPlural(template, args);
  }

  String result = template;
  for (final entry in args.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value.toString());
  }
  return result;
}
