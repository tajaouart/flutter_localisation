// test/provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localisation/saas_translations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock generated localizations for testing
class MockAppLocalizations {
  static const supportedLocales = [Locale('en'), Locale('es')];

  String hello(String name) => 'Hello $name!';
  String welcomeMessage(String username) => 'Welcome back, $username!';
  String get appTitle => 'Test App';
  String get simpleGreeting => 'Good morning!';
  String itemsInCart(int count) {
    if (count == 0) return 'No items';
    if (count == 1) return '1 item';
    return '$count items';
  }
}

// Test SaaS service that can be controlled for testing
class TestSaaSTranslationService extends SaaSTranslationService {
  final Map<String, Map<String, String>> _testOverrides = {};

  void setTestOverrides(String locale, Map<String, String> overrides) {
    _testOverrides[locale] = overrides;
    notifyListeners(); // Notify listeners of changes
  }

  @override
  String? getOverride(String locale, String key) {
    return _testOverrides[locale]?[key];
  }

  @override
  bool hasOverride(String locale, String key) {
    return _testOverrides[locale]?.containsKey(key) ?? false;
  }

  @override
  Map<String, int> getCacheStatus() {
    return _testOverrides
        .map((locale, overrides) => MapEntry(locale, overrides.length));
  }
}

void main() {
  group('SaaS Translation Provider Tests', () {
    late TestSaaSTranslationService service;
    late MockAppLocalizations mockLocalizations;

    setUp(() {
      service = TestSaaSTranslationService();
      mockLocalizations = MockAppLocalizations();
    });

    testWidgets('SaaSTranslationProvider provides service correctly',
        (tester) async {
      late SaaSTranslationService retrievedService;

      await tester.pumpWidget(
        MaterialApp(
          home: SaaSTranslationProvider(
            service: service,
            generatedLocalizations: mockLocalizations,
            child: Builder(
              builder: (context) {
                retrievedService = SaaSTranslationProvider.of(context).service;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(retrievedService, equals(service));
    });

    testWidgets('Context extension provides SaaSTranslations', (tester) async {
      late SaaSTranslations translations;

      await tester.pumpWidget(
        MaterialApp(
          home: SaaSTranslationProvider(
            service: service,
            generatedLocalizations: mockLocalizations,
            child: Builder(
              builder: (context) {
                translations = context.tr;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(translations, isA<SaaSTranslations>());
      expect(translations.service, equals(service));
      expect(translations.generatedLocalizations, equals(mockLocalizations));
    });

    group('ICU Plural Processing Tests', () {
      test('handles zero case correctly', () {
        const template =
            '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
        final result =
            TestSaaSTranslations.testHandleICUPlural(template, {'count': 0});

        expect(result, equals('🛒 No items'));
      });

      test('handles one case correctly', () {
        const template =
            '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
        final result =
            TestSaaSTranslations.testHandleICUPlural(template, {'count': 1});

        expect(result, equals('🛒 1 item'));
      });

      test('handles other case correctly', () {
        const template =
            '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
        final result =
            TestSaaSTranslations.testHandleICUPlural(template, {'count': 5});

        expect(result, equals('🛒 5 items'));
      });

      test('handles complex ICU with emojis and placeholders', () {
        const template =
            '{count, plural, =0{🛒 SaaS: No items in cart} =1{🛒 SaaS: 1 amazing item} other{🛒 SaaS: {count} amazing items}}';
        final result =
            TestSaaSTranslations.testHandleICUPlural(template, {'count': 10});

        expect(result, equals('🛒 SaaS: 10 amazing items'));
      });

      test('handles nested braces correctly', () {
        const template =
            '{count, plural, =0{No {type} items} =1{1 {type} item} other{{count} {type} items}}';
        final result = TestSaaSTranslations.testHandleICUPlural(
            template, {'count': 3, 'type': 'special'});

        expect(result, equals('3 special items'));
      });

      test('handles malformed ICU gracefully', () {
        const template = '{count, plural, broken}';
        final result =
            TestSaaSTranslations.testHandleICUPlural(template, {'count': 1});

        expect(result, equals(template)); // Should return original template
      });

      test('handles missing count parameter', () {
        const template = '{count, plural, =0{No items} other{{count} items}}';
        final result = TestSaaSTranslations.testHandleICUPlural(template, {});

        expect(result, equals('No items')); // Should default to count = 0
      });
    });

    group('Simple String Replacement Tests', () {
      test('replaces basic placeholders', () {
        const template = 'Hello {name}!';
        final result = TestSaaSTranslations.testSimpleStringReplacement(
            template, {'name': 'World'});

        expect(result, equals('Hello World!'));
      });

      test('handles multiple placeholders', () {
        const template = 'Welcome {username}, you have {count} messages';
        final result =
            TestSaaSTranslations.testSimpleStringReplacement(template, {
          'username': 'Alice',
          'count': 5,
        });

        expect(result, equals('Welcome Alice, you have 5 messages'));
      });

      test('handles ICU plurals by delegating to ICU processor', () {
        const template = '{count, plural, =0{No items} other{{count} items}}';
        final result = TestSaaSTranslations.testSimpleStringReplacement(
            template, {'count': 3});

        expect(result, equals('3 items'));
      });

      test('handles missing placeholders gracefully', () {
        const template = 'Hello {name}!';
        final result =
            TestSaaSTranslations.testSimpleStringReplacement(template, {});

        expect(result,
            equals('Hello {name}!')); // Should leave placeholder unchanged
      });
    });

    group('Translation Resolution Tests', () {
      testWidgets('uses SaaS override when available', (tester) async {
        // Set up SaaS override using the test service
        service.setTestOverrides('en', {'hello': 'SaaS Hello {name}!'});

        String? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: MockAppLocalizations.supportedLocales,
            home: SaaSTranslationProvider(
              service: service,
              generatedLocalizations: mockLocalizations,
              child: Builder(
                builder: (context) {
                  result = context.tr.translate(
                    'hello',
                    {'name': 'World'},
                    () => mockLocalizations.hello('World'),
                  );
                  return Container();
                },
              ),
            ),
          ),
        );

        expect(result, equals('SaaS Hello World!'));
      });

      testWidgets('falls back to generated localizations when no override',
          (tester) async {
        String? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: MockAppLocalizations.supportedLocales,
            home: SaaSTranslationProvider(
              service: service,
              generatedLocalizations: mockLocalizations,
              child: Builder(
                builder: (context) {
                  result = context.tr.translate(
                    'hello',
                    {'name': 'World'},
                    () => mockLocalizations.hello('World'),
                  );
                  return Container();
                },
              ),
            ),
          ),
        );

        expect(result,
            equals('Hello World!')); // Should use generated localization
      });
    });

    group('Service Integration Tests', () {
      test('service can store and retrieve overrides', () {
        service.setTestOverrides('en', {'test': 'Test Override'});

        expect(service.getOverride('en', 'test'), equals('Test Override'));
        expect(service.hasOverride('en', 'test'), isTrue);
        expect(service.hasOverride('en', 'missing'), isFalse);
      });

      test('service handles multiple locales', () {
        service.setTestOverrides('en', {'greeting': 'Hello'});
        service.setTestOverrides('es', {'greeting': 'Hola'});

        expect(service.getOverride('en', 'greeting'), equals('Hello'));
        expect(service.getOverride('es', 'greeting'), equals('Hola'));
      });

      test('service notifies listeners on updates', () {
        bool notified = false;
        service.addListener(() => notified = true);

        service.setTestOverrides('en', {'test': 'value'});

        expect(notified, isTrue);
      });

      test('service cache status reflects overrides', () {
        service.setTestOverrides('en', {'key1': 'value1', 'key2': 'value2'});
        service.setTestOverrides('es', {'key1': 'valor1'});

        final status = service.getCacheStatus();
        expect(status['en'], equals(2));
        expect(status['es'], equals(1));
      });
    });
  });
}

// Test helper class to expose private methods for testing
class TestSaaSTranslations {
  static String testHandleICUPlural(
      String template, Map<String, dynamic> args) {
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

  static String testSimpleStringReplacement(
      String template, Map<String, dynamic> args) {
    if (template.contains('plural,')) {
      return testHandleICUPlural(template, args);
    }

    String result = template;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }
}
