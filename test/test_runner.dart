#!/usr/bin/env dart
// test_runner.dart

void main() {
  print('🧪 Running FlutterLocalisation Translations Tests');
  print('=' * 50);

  // Test 1: Zero case
  testICUPlural(
    'Test 1: Zero case',
    '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}',
    {'count': 0},
    '🛒 FlutterLocalisation: No items in cart',
  );

  // Test 2: One case
  testICUPlural(
    'Test 2: One case',
    '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}',
    {'count': 1},
    '🛒 FlutterLocalisation: 1 amazing item',
  );

  // Test 3: Other case
  testICUPlural(
    'Test 3: Other case (10 items)',
    '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}',
    {'count': 10},
    '🛒 FlutterLocalisation: 10 amazing items',
  );

  // Test 4: Spanish template
  testICUPlural(
    'Test 4: Spanish template',
    '{count, plural, =0{🛒 FlutterLocalisation: Sin artículos en carrito} =1{🛒 FlutterLocalisation: 1 artículo increíble} other{🛒 FlutterLocalisation: {count} artículos increíbles}}',
    {'count': 5},
    '🛒 FlutterLocalisation: 5 artículos increíbles',
  );

  // Test 5: Simple replacement
  testSimpleReplacement(
    'Test 5: Simple placeholder',
    'Hello {name}!',
    {'name': 'World'},
    'Hello World!',
  );

  // Test 6: Complex replacement
  testSimpleReplacement(
    'Test 6: Multiple placeholders',
    'Welcome back, {username}! You have {count} messages.',
    {'username': 'Developer', 'count': 5},
    'Welcome back, Developer! You have 5 messages.',
  );

  print('\n✅ All tests completed!');
  print('If any tests failed, check the ICU processing logic.');
}

void testICUPlural(String testName, String template, Map<String, dynamic> args,
    String expected) {
  try {
    final result = processICUPlural(template, args);

    if (result == expected) {
      print('✅ $testName: PASSED');
    } else {
      print('❌ $testName: FAILED');
      print('   Expected: $expected');
      print('   Got:      $result');
    }
  } catch (error) {
    print('❌ $testName: ERROR - $error');
  }
}

void testSimpleReplacement(String testName, String template,
    Map<String, dynamic> args, String expected) {
  try {
    final result = processSimpleReplacement(template, args);

    if (result == expected) {
      print('✅ $testName: PASSED');
    } else {
      print('❌ $testName: FAILED');
      print('   Expected: $expected');
      print('   Got:      $result');
    }
  } catch (error) {
    print('❌ $testName: ERROR - $error');
  }
}

/// ICU plural processing implementation
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

/// Simple string replacement
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
