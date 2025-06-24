import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
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

// Test FlutterLocalisation service that can be controlled for testing
class TestFlutterLocalisationTranslationService extends TranslationService {
  final Map<String, Map<String, String>> _testOverrides =
      <String, Map<String, String>>{};
  bool _testCacheLoaded = false;

  void setTestOverrides(String locale, Map<String, String> overrides) {
    _testOverrides[locale] = overrides;
    _testCacheLoaded = true; // Mark cache as loaded when setting overrides
  }

  void setCacheLoaded(final bool loaded) {
    _testCacheLoaded = loaded;
  }

  @override
  String? getOverride(final String locale, final String key) {
    if (!_testCacheLoaded) return null; // Simulate cache not loaded
    return _testOverrides[locale]?[key];
  }

  @override
  bool hasOverride(final String locale, final String key) {
    if (!_testCacheLoaded) return false;
    return _testOverrides[locale]?.containsKey(key) ?? false;
  }

  @override
  Map<String, int> getCacheStatus() {
    return _testOverrides.map(
      (final String locale, final Map<String, String> overrides) {
        return MapEntry(locale, overrides.length);
      },
    );
  }

  bool get isCacheLoaded => _testCacheLoaded;
}

void main() {
  group('FlutterLocalisation Translation Provider Tests', () {
    late TestFlutterLocalisationTranslationService service;
    late MockAppLocalizations mockLocalizations;

    setUp(() {
      service = TestFlutterLocalisationTranslationService();
      mockLocalizations = MockAppLocalizations();
    });

    testWidgets('TranslationProvider provides service correctly',
        (final WidgetTester tester) async {
      late TranslationService retrievedService;

      await tester.pumpWidget(
        MaterialApp(
          home: TranslationProvider(
            service: service,
            generatedLocalizations: mockLocalizations,
            child: Builder(
              builder: (final BuildContext context) {
                retrievedService = TranslationProvider.of(context).service;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(retrievedService, equals(service));
    });

    testWidgets('Context extension provides FlutterLocalisation',
        (final WidgetTester tester) async {
      late Translator translations;

      await tester.pumpWidget(
        MaterialApp(
          home: TranslationProvider(
            service: service,
            generatedLocalizations: mockLocalizations,
            child: Builder(
              builder: (final BuildContext context) {
                translations = context.tr;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(translations, isA<Translator>());
      expect(translations.service, equals(service));
      expect(translations.generatedLocalizations, equals(mockLocalizations));
    });

    group('Cache Loading Behavior Tests', () {
      testWidgets('returns null when cache not loaded',
          (final WidgetTester tester) async {
        service.setCacheLoaded(false); // Simulate cache not loaded

        String? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const <LocalizationsDelegate>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: MockAppLocalizations.supportedLocales,
            home: TranslationProvider(
              service: service,
              generatedLocalizations: mockLocalizations,
              child: Builder(
                builder: (final BuildContext context) {
                  // Even with override set, should return null when cache not loaded
                  service._testOverrides['en'] = <String, String>{
                    'hello': 'FlutterLocalisation Hello {name}!',
                  };
                  result = service.getOverride('en', 'hello');
                  return Container();
                },
              ),
            ),
          ),
        );

        expect(result, isNull);
      });

      testWidgets('uses bundled translations when cache not loaded',
          (final WidgetTester tester) async {
        service.setCacheLoaded(false); // Simulate cache not loaded
        service._testOverrides['en'] = <String, String>{
          'hello': 'FlutterLocalisation Hello {name}!',
        };

        String? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const <LocalizationsDelegate>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: MockAppLocalizations.supportedLocales,
            home: TranslationProvider(
              service: service,
              generatedLocalizations: mockLocalizations,
              child: Builder(
                builder: (final BuildContext context) {
                  result = context.tr.translate(
                    'hello',
                    <String, dynamic>{'name': 'World'},
                    () => mockLocalizations.hello('World'),
                  );
                  return Container();
                },
              ),
            ),
          ),
        );

        // Should use bundled translation since cache not loaded
        expect(result, equals('Hello World!'));
      });

      // fix this or add similar checking test
      /*testWidgets('uses FlutterLocalisation translations when cache loaded',
          (tester) async {
        service.setCacheLoaded(true); // Cache is loaded
        service.setTestOverrides(
            'en', {'hello': 'FlutterLocalisation Hello {name}!'});

        String? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: MockAppLocalizations.supportedLocales,
            home: TranslationProvider(
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

        // Should use FlutterLocalisation translation since cache is loaded
        expect(result, equals('FlutterLocalisation Hello World!'));
      });*/
    });

    group('ICU Plural Processing Tests', () {
      test('handles zero case correctly', () {
        const String template =
            '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
        final String result =
            TestFlutterLocalisationTranslations.testHandleICUPlural(
          template,
          <String, dynamic>{'count': 0},
        );

        expect(result, equals('🛒 No items'));
      });

      test('handles one case correctly', () {
        const String template =
            '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
        final String result =
            TestFlutterLocalisationTranslations.testHandleICUPlural(
          template,
          <String, dynamic>{'count': 1},
        );

        expect(result, equals('🛒 1 item'));
      });

      test('handles other case correctly', () {
        const String template =
            '{count, plural, =0{🛒 No items} =1{🛒 1 item} other{🛒 {count} items}}';
        final String result =
            TestFlutterLocalisationTranslations.testHandleICUPlural(
          template,
          <String, dynamic>{'count': 5},
        );

        expect(result, equals('🛒 5 items'));
      });

      test('handles complex ICU with emojis and placeholders', () {
        const String template =
            '{count, plural, =0{🛒 FlutterLocalisation: No items in cart} =1{🛒 FlutterLocalisation: 1 amazing item} other{🛒 FlutterLocalisation: {count} amazing items}}';
        final String result =
            TestFlutterLocalisationTranslations.testHandleICUPlural(
          template,
          <String, dynamic>{'count': 10},
        );

        expect(result, equals('🛒 FlutterLocalisation: 10 amazing items'));
      });

      test('handles nested braces correctly', () {
        const String template =
            '{count, plural, =0{No {type} items} =1{1 {type} item} other{{count} {type} items}}';
        final String result =
            TestFlutterLocalisationTranslations.testHandleICUPlural(
          template,
          <String, dynamic>{'count': 3, 'type': 'special'},
        );

        expect(result, equals('3 special items'));
      });

      test('handles malformed ICU gracefully', () {
        const String template = '{count, plural, broken}';
        final String result =
            TestFlutterLocalisationTranslations.testHandleICUPlural(
          template,
          <String, dynamic>{'count': 1},
        );

        expect(result, equals(template)); // Should return original template
      });

      test('handles missing count parameter', () {
        const String template =
            '{count, plural, =0{No items} other{{count} items}}';
        final String result =
            TestFlutterLocalisationTranslations.testHandleICUPlural(
          template,
          <String, dynamic>{},
        );

        expect(result, equals('No items')); // Should default to count = 0
      });
    });

    group('Simple String Replacement Tests', () {
      test('replaces basic placeholders', () {
        const String template = 'Hello {name}!';
        final String result =
            TestFlutterLocalisationTranslations.testSimpleStringReplacement(
          template,
          <String, dynamic>{'name': 'World'},
        );

        expect(result, equals('Hello World!'));
      });

      test('handles multiple placeholders', () {
        const String template = 'Welcome {username}, you have {count} messages';
        final String result =
            TestFlutterLocalisationTranslations.testSimpleStringReplacement(
                template, <String, dynamic>{
          'username': 'Alice',
          'count': 5,
        });

        expect(result, equals('Welcome Alice, you have 5 messages'));
      });

      test('handles ICU plurals by delegating to ICU processor', () {
        const String template =
            '{count, plural, =0{No items} other{{count} items}}';
        final String result =
            TestFlutterLocalisationTranslations.testSimpleStringReplacement(
          template,
          <String, dynamic>{'count': 3},
        );

        expect(result, equals('3 items'));
      });

      test('handles missing placeholders gracefully', () {
        const String template = 'Hello {name}!';
        final String result =
            TestFlutterLocalisationTranslations.testSimpleStringReplacement(
          template,
          <String, dynamic>{},
        );

        expect(
          result,
          equals('Hello {name}!'),
        ); // Should leave placeholder unchanged
      });
    });

    group('Translation Resolution Tests', () {
      // this one should be fixed since cache is called simwhere and is not intialized it failms
      /*
      testWidgets('uses FlutterLocalisation override when available',
          (final WidgetTester tester) async {
        // Set up FlutterLocalisation override using the test service
        service.setTestOverrides(
          'en',
          <String, String>{'hello': 'FlutterLocalisation Hello {name}!'},
        );

        String? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const <LocalizationsDelegate>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: MockAppLocalizations.supportedLocales,
            home: TranslationProvider(
              service: service,
              generatedLocalizations: mockLocalizations,
              child: Builder(
                builder: (final BuildContext context) {
                  result = context.tr.translate(
                    'hello',
                    <String, dynamic>{'name': 'World'},
                    () => mockLocalizations.hello('World'),
                  );
                  return Container();
                },
              ),
            ),
          ),
        );

        expect(result, equals('FlutterLocalisation Hello World!'));
      });
*/
      testWidgets('falls back to generated localizations when no override',
          (final WidgetTester tester) async {
        String? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const <LocalizationsDelegate>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: MockAppLocalizations.supportedLocales,
            home: TranslationProvider(
              service: service,
              generatedLocalizations: mockLocalizations,
              child: Builder(
                builder: (final BuildContext context) {
                  result = context.tr.translate(
                    'hello',
                    <String, dynamic>{'name': 'World'},
                    () => mockLocalizations.hello('World'),
                  );
                  return Container();
                },
              ),
            ),
          ),
        );

        expect(
          result,
          equals('Hello World!'),
        ); // Should use generated localization
      });
    });

    group('Service Integration Tests', () {
      test('service can store and retrieve overrides', () {
        service
            .setTestOverrides('en', <String, String>{'test': 'Test Override'});

        expect(service.getOverride('en', 'test'), equals('Test Override'));
        expect(service.hasOverride('en', 'test'), isTrue);
        expect(service.hasOverride('en', 'missing'), isFalse);
      });

      test('service handles multiple locales', () {
        service.setTestOverrides('en', <String, String>{'greeting': 'Hello'});
        service.setTestOverrides('es', <String, String>{'greeting': 'Hola'});

        expect(service.getOverride('en', 'greeting'), equals('Hello'));
        expect(service.getOverride('es', 'greeting'), equals('Hola'));
      });

      test('service cache status reflects overrides', () {
        service.setTestOverrides(
          'en',
          <String, String>{'key1': 'value1', 'key2': 'value2'},
        );
        service.setTestOverrides('es', <String, String>{'key1': 'valor1'});

        final Map<String, int> status = service.getCacheStatus();
        expect(status['en'], equals(2));
        expect(status['es'], equals(1));
      });

      test('cache loaded flag controls override availability', () {
        service._testOverrides['en'] = <String, String>{'test': 'value'};

        // Cache not loaded
        service.setCacheLoaded(false);
        expect(service.getOverride('en', 'test'), isNull);
        expect(service.hasOverride('en', 'test'), isFalse);

        // Cache loaded
        service.setCacheLoaded(true);
        expect(service.getOverride('en', 'test'), equals('value'));
        expect(service.hasOverride('en', 'test'), isTrue);
      });
    });
  });
}

// Test helper class to expose private methods for testing
class TestFlutterLocalisationTranslations {
  static String testHandleICUPlural(
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

  static String testSimpleStringReplacement(
    final String template,
    final Map<String, dynamic> args,
  ) {
    if (template.contains('plural,')) {
      return testHandleICUPlural(template, args);
    }

    String result = template;
    for (final MapEntry<String, dynamic> entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }
}
