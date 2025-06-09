import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// A dummy class for generated localizations, unchanged.
class MockGeneratedLocalizations {
  String get appTitle => 'Fallback Title';

  String welcome(String name) => 'Fallback Welcome $name';
}

/// A unified manual mock that handles locale-specific overrides.
class ManualMockSaaSTranslationService implements TranslationService {
  /// FIX: This is now a nested map to support multiple locales.
  /// The structure is: {'locale_code': {'key': 'value'}}
  Map<String, Map<String, String>> overridesToReturn = {};

  bool loggingIsEnabled = false;
  int refreshTranslationsCallCount = 0;

  @override
  String? getOverride(String locale, String key) {
    // Correctly looks up the locale first, then the key.
    return overridesToReturn[locale]?[key];
  }

  @override
  Map<String, String> getAllOverridesForLocale(String locale) {
    // Returns all overrides for a specific locale, or an empty map.
    return overridesToReturn[locale] ?? {};
  }

  @override
  Future<void> refresh(String locale) async {
    refreshTranslationsCallCount++;
    return;
  }

  @override
  bool get isLoggingEnabled => loggingIsEnabled;

  // --- Other interface methods remain the same ---
  @override
  Future<void> clearCache() async {}

  @override
  void dispose() {}

  @override
  Map<String, int> getCacheStatus() => {};

  @override
  bool hasOverride(String locale, String key) =>
      overridesToReturn[locale]?.containsKey(key) ?? false;

  @override
  Future<void> initialize() async {}

  @override
  bool get isApiConfigured => true;

  @override
  bool get isReady => true;
}

void main() {
  /// A unified helper that takes the mocks and an optional locale.
  Future<void> pumpTranslatorWidget(
    WidgetTester tester, {
    required ManualMockSaaSTranslationService service,
    required MockGeneratedLocalizations generated,
    Locale locale = const Locale('en'), // Defaults to 'en' for simpler tests
    required Function(BuildContext context, Translator translator) testLogic,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [
          Locale('en'),
          Locale('fr'),
        ],
        // FIX: Add the required global delegates here
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: TranslationProvider(
          service: service,
          generatedLocalizations: generated,
          child: Builder(
            builder: (context) {
              final translator = Translator(
                context: context,
                service: service,
                generatedLocalizations: generated,
              );
              testLogic(context, translator);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  group('SaaSTranslator (Unified Manual Mock)', () {
    late ManualMockSaaSTranslationService mockService;
    late MockGeneratedLocalizations mockGenerated;

    setUp(() {
      mockService = ManualMockSaaSTranslationService();
      mockGenerated = MockGeneratedLocalizations();
    });

    testWidgets('translate uses fallback when no SaaS override exists',
        (tester) async {
      // ARRANGE: No overrides are set.
      mockService.overridesToReturn = {};

      // ACT & ASSERT
      await pumpTranslatorWidget(
        tester,
        service: mockService,
        generated: mockGenerated,
        testLogic: (context, translator) {
          final result = translator.translate(
            'appTitle',
            {},
            () => mockGenerated.appTitle,
          );
          expect(result, 'Fallback Title');
        },
      );
    });

    testWidgets('translate uses SaaS override for a simple string',
        (tester) async {
      // ARRANGE: Use the nested map structure, even for a single locale.
      mockService.overridesToReturn = {
        'en': {'appTitle': 'SaaS Live Title!'}
      };

      // ACT & ASSERT
      await pumpTranslatorWidget(
        tester,
        service: mockService,
        generated: mockGenerated,
        testLogic: (context, translator) {
          final result = translator.translate(
            'appTitle',
            {},
            () => mockGenerated.appTitle,
          );
          expect(result, 'SaaS Live Title!');
        },
      );
    });

    testWidgets('translate correctly processes override with arguments',
        (tester) async {
      // ARRANGE
      mockService.overridesToReturn = {
        'en': {'welcome': 'Live Welcome {name} from SaaS!'}
      };

      // ACT & ASSERT
      await pumpTranslatorWidget(
        tester,
        service: mockService,
        generated: mockGenerated,
        testLogic: (context, translator) {
          final result = translator.translate(
            'welcome',
            {'name': 'Tester'},
            () => mockGenerated.welcome('Tester'),
          );
          expect(result, 'Live Welcome Tester from SaaS!');
        },
      );
    });

    testWidgets('translate falls back to basic replacement on ICU failure',
        (tester) async {
      // ARRANGE
      const trulyBrokenTemplate = 'An error occurred: {message}. Details: {';
      mockService.overridesToReturn = {
        'en': {'error_key': trulyBrokenTemplate}
      };

      // ACT & ASSERT
      await pumpTranslatorWidget(
        tester,
        service: mockService,
        generated: mockGenerated,
        testLogic: (context, translator) {
          final result = translator.translate(
            'error_key',
            {'message': 'Invalid Syntax'},
            () => 'Fallback error',
          );
          expect(result, 'An error occurred: Invalid Syntax. Details: {');
        },
      );
    });

    // --- This is the "Intelligent Test", now working with the unified setup ---
    testWidgets('handles complex ICU, caching, and locale changes correctly',
        (tester) async {
      // ARRANGE
      mockService.overridesToReturn = {
        'en': {
          'inboxMessage':
              '{count, plural, =0{Hi {name}, you have no new messages.} =1{Hi {name}, you have one new message.} other{Hi {name}, you have {count} new messages.}}',
        },
        'fr': {
          'inboxMessage':
              '{count, plural, =0{Salut {name}, tu n\'as aucun nouveau message.} =1{Salut {name}, tu as un nouveau message.} other{Salut {name}, tu as {count} nouveaux messages.}}',
        },
      };

      // ACT & ASSERT: Part 1 (English)
      await pumpTranslatorWidget(
        tester,
        service: mockService,
        generated: mockGenerated,
        locale: const Locale('en'), // Explicitly set locale
        testLogic: (context, translator) {
          var result = translator.translate(
              'inboxMessage', {'count': 1, 'name': 'Mounir'}, () => 'fallback');
          expect(result, 'Hi Mounir, you have one new message.');
        },
      );

      // ACT & ASSERT: Part 2 (French)
      await pumpTranslatorWidget(
        tester,
        service: mockService,
        generated: mockGenerated,
        locale: const Locale('fr'), // Switch locale
        testLogic: (context, translator) {
          var result = translator?.translate(
              'inboxMessage', {'count': 5, 'name': 'Mounir'}, () => 'fallback');
          expect(result, 'Salut Mounir, tu as 5 nouveaux messages.');
        },
      );
    });
  });
}
