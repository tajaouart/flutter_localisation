// test/icu_processing_test.dart
import 'package:test/test.dart';

void main() {
  group('ICU Plural Processing Tests', () {
    test('should handle zero case correctly', () {
      const String template =
          '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 0});

      expect(result, equals('🛒 No items'));
    });

    test('should handle one case correctly', () {
      const String template =
          '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 1});

      expect(result, equals('🛒 1 item'));
    });

    test('should handle other case correctly', () {
      const String template =
          '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 5});

      expect(result, equals('🛒 5 items'));
    });

    test('should handle complex FlutterLocalisation ICU template', () {
      const String template =
          '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 10});

      expect(result, equals('🛒 FlutterLocalisation: 10 amazing items'));
    });

    test('should handle Spanish FlutterLocalisation ICU template', () {
      const String template =
          '{count, plural, =0{🛒 FlutterLocalisation: Sin artículos en carrito} =1{🛒 FlutterLocalisation: 1 artículo increíble} other{🛒 FlutterLocalisation: {count} artículos increíbles}}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 3});

      expect(result, equals('🛒 FlutterLocalisation: 3 artículos increíbles'));
    });

    test('should handle nested placeholders', () {
      const String template =
          '{count, plural, =0{No {type} items} =1{1 {type} item} other{{count} {type} items}}';
      final String result = processICUPlural(
        template,
        <String, dynamic>{'count': 4, 'type': 'special'},
      );

      expect(result, equals('4 special items'));
    });

    test('should handle malformed ICU gracefully', () {
      const String template = '{count, plural, broken}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 1});

      expect(result, equals(template)); // Should return original template
    });

    test('should handle missing count parameter', () {
      const String template =
          '{count, plural, =0{No items} other{{count} items}}';
      final String result = processICUPlural(template, <String, dynamic>{});

      expect(result, equals('No items')); // Should default to count = 0
    });

    test('should handle emojis and special characters', () {
      const String template =
          '{count, plural, =0{🚫 Empty} =1{⭐ One star} other{⭐ {count} stars}}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 5});

      expect(result, equals('⭐ 5 stars'));
    });

    test('should handle complex spacing in ICU', () {
      const String template =
          '{count,plural,=0{No items}=1{One item}other{{count} items}}';
      final String result =
          processICUPlural(template, <String, dynamic>{'count': 2});

      expect(result, equals('2 items'));
    });
  });

  group('Simple String Replacement Tests', () {
    test('should replace basic placeholders', () {
      const String template = 'Hello {name}!';
      final String result = processSimpleReplacement(
        template,
        <String, dynamic>{'name': 'World'},
      );

      expect(result, equals('Hello World!'));
    });

    test('should handle multiple placeholders', () {
      const String template = 'Welcome {username}, you have {count} messages';
      final String result =
          processSimpleReplacement(template, <String, dynamic>{
        'username': 'Alice',
        'count': 5,
      });

      expect(result, equals('Welcome Alice, you have 5 messages'));
    });

    test('should handle missing placeholders gracefully', () {
      const String template = 'Hello {name}!';
      final String result =
          processSimpleReplacement(template, <String, dynamic>{});

      expect(
        result,
        equals('Hello {name}!'),
      ); // Should leave placeholder unchanged
    });

    test('should delegate ICU plurals to ICU processor', () {
      const String template =
          '{count, plural, =0{No items} other{{count} items}}';
      final String result =
          processSimpleReplacement(template, <String, dynamic>{'count': 3});

      expect(result, equals('3 items'));
    });
  });
}

/// Test implementation of ICU plural processing
/// This is a copy of the logic from the provider for testing
String processICUPlural(
  final String template,
  final Map<String, dynamic> args,
) {
  try {
    final int count = args['count'] as int? ?? 0;

    final Map<String, String> cases = <String, String>{};

    final Map<String, RegExp> patterns = <String, RegExp>{
      'zero': RegExp(r'=0\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'),
      'one': RegExp(r'=1\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'),
      'other': RegExp(r'other\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'),
    };

    patterns.forEach((final String caseName, final RegExp pattern) {
      final RegExpMatch? match = pattern.firstMatch(template);
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
    for (final MapEntry<String, dynamic> entry in args.entries) {
      final String placeholder = '{${entry.key}}';
      final String value = entry.value.toString();
      result = result.replaceAll(placeholder, value);
    }

    return result;
  } catch (error) {
    return template;
  }
}

/// Test implementation of simple string replacement
String processSimpleReplacement(
  final String template,
  final Map<String, dynamic> args,
) {
  if (template.contains('plural,')) {
    return processICUPlural(template, args);
  }

  String result = template;
  for (final MapEntry<String, dynamic> entry in args.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value.toString());
  }
  return result;
}
