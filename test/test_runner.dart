#!/usr/bin/env dart
// test_runner.dart

import 'package:flutter/material.dart';

void main() {
  debugPrint('🧪 Running FlutterLocalisation Translations Tests');
  debugPrint('=' * 50);

  // Test 1: Zero case
  testICUPlural(
    'Test 1: Zero case',
    '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}',
    <String, dynamic>{'count': 0},
    '🛒 FlutterLocalisation: No items in cart',
  );

  // Test 2: One case
  testICUPlural(
    'Test 2: One case',
    '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}',
    <String, dynamic>{'count': 1},
    '🛒 FlutterLocalisation: 1 amazing item',
  );

  // Test 3: Other case
  testICUPlural(
    'Test 3: Other case (10 items)',
    '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}',
    <String, dynamic>{'count': 10},
    '🛒 FlutterLocalisation: 10 amazing items',
  );

  // Test 4: Spanish template
  testICUPlural(
    'Test 4: Spanish template',
    '{count, plural, =0{🛒 FlutterLocalisation: Sin artículos en carrito} =1{🛒 FlutterLocalisation: 1 artículo increíble} other{🛒 FlutterLocalisation: {count} artículos increíbles}}',
    <String, dynamic>{'count': 5},
    '🛒 FlutterLocalisation: 5 artículos increíbles',
  );

  // Test 5: Simple replacement
  testSimpleReplacement(
    'Test 5: Simple placeholder',
    'Hello {name}!',
    <String, dynamic>{'name': 'World'},
    'Hello World!',
  );

  // Test 6: Complex replacement
  testSimpleReplacement(
    'Test 6: Multiple placeholders',
    'Welcome back, {username}! You have {count} messages.',
    <String, dynamic>{'username': 'Developer', 'count': 5},
    'Welcome back, Developer! You have 5 messages.',
  );

  debugPrint('\n✅ All tests completed!');
  debugPrint('If any tests failed, check the ICU processing logic.');
}

void testICUPlural(
  final String testName,
  final String template,
  final Map<String, dynamic> args,
  final String expected,
) {
  try {
    final String result = processICUPlural(template, args);

    if (result == expected) {
      debugPrint('✅ $testName: PASSED');
    } else {
      debugPrint('❌ $testName: FAILED');
      debugPrint('   Expected: $expected');
      debugPrint('   Got:      $result');
    }
  } on Exception catch (error) {
    debugPrint('❌ $testName: ERROR - $error');
  }
}

void testSimpleReplacement(
  final String testName,
  final String template,
  final Map<String, dynamic> args,
  final String expected,
) {
  try {
    final String result = processSimpleReplacement(template, args);

    if (result == expected) {
      debugPrint('✅ $testName: PASSED');
    } else {
      debugPrint('❌ $testName: FAILED');
      debugPrint('   Expected: $expected');
      debugPrint('   Got:      $result');
    }
  } on Exception catch (error) {
    debugPrint('❌ $testName: ERROR - $error');
  }
}

/// ICU plural processing implementation
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
  } on Exception catch (_) {
    return template;
  }
}

/// Simple string replacement
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
