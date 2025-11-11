// test/extensions_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_test/flutter_test.dart';

// Test service for testing
class TestTranslationService extends TranslationService {
  @override
  String? getOverride(final String locale, final String key) => null;

  @override
  bool hasOverride(final String locale, final String key) => false;

  @override
  Map<String, int> getCacheStatus() => <String, int>{};
}

void main() {
  group('FlutterLocalisationExtension - tr getter', () {
    testWidgets('returns Translator when provider is available',
        (final WidgetTester tester) async {
      final TestTranslationService service = TestTranslationService();
      Translator? translator;

      await tester.pumpWidget(
        MaterialApp(
          home: TranslationProvider(
            service: service,
            generatedLocalizations: null,
            child: Builder(
              builder: (final BuildContext context) {
                translator = context.tr;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(translator, isNotNull);
      expect(translator, isA<Translator>());
      expect(translator!.service, equals(service));
    });

    testWidgets('creates new Translator instance on each access',
        (final WidgetTester tester) async {
      final TestTranslationService service = TestTranslationService();
      Translator? translator1;
      Translator? translator2;

      await tester.pumpWidget(
        MaterialApp(
          home: TranslationProvider(
            service: service,
            generatedLocalizations: null,
            child: Builder(
              builder: (final BuildContext context) {
                translator1 = context.tr;
                translator2 = context.tr;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(translator1, isNotNull);
      expect(translator2, isNotNull);
      // Each access creates a new instance
      expect(identical(translator1, translator2), isFalse);
      // But both reference the same service
      expect(translator1!.service, equals(translator2!.service));
    });

    testWidgets('throws when provider is not in widget tree',
        (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final BuildContext context) {
              expect(() => context.tr, throwsAssertionError);
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('FlutterLocalisationExtension - translations getter', () {
    testWidgets('returns service when provider is available',
        (final WidgetTester tester) async {
      final TestTranslationService service = TestTranslationService();
      TranslationService? retrievedService;

      await tester.pumpWidget(
        MaterialApp(
          home: TranslationProvider(
            service: service,
            generatedLocalizations: null,
            child: Builder(
              builder: (final BuildContext context) {
                retrievedService = context.translations;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(retrievedService, isNotNull);
      expect(retrievedService, equals(service));
    });

    testWidgets('returns null when provider is not in widget tree',
        (final WidgetTester tester) async {
      TranslationService? retrievedService;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final BuildContext context) {
              retrievedService = context.translations;
              return Container();
            },
          ),
        ),
      );

      expect(retrievedService, isNull);
    });

    testWidgets('uses maybeOf internally (does not throw)',
        (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final BuildContext context) {
              // Should not throw, just return null
              final TranslationService? service = context.translations;
              expect(service, isNull);
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('FlutterLocalisationExtension - integration', () {
    testWidgets('both getters work correctly with same provider',
        (final WidgetTester tester) async {
      final TestTranslationService service = TestTranslationService();
      Translator? translator;
      TranslationService? directService;

      await tester.pumpWidget(
        MaterialApp(
          home: TranslationProvider(
            service: service,
            generatedLocalizations: null,
            child: Builder(
              builder: (final BuildContext context) {
                translator = context.tr;
                directService = context.translations;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(translator, isNotNull);
      expect(directService, isNotNull);
      expect(translator!.service, equals(directService));
      expect(translator!.service, equals(service));
    });

    testWidgets('extensions work with nested widgets',
        (final WidgetTester tester) async {
      final TestTranslationService service = TestTranslationService();
      Translator? innerTranslator;
      TranslationService? innerService;

      await tester.pumpWidget(
        MaterialApp(
          home: TranslationProvider(
            service: service,
            generatedLocalizations: null,
            child: Column(
              children: <Widget>[
                Builder(
                  builder: (final BuildContext outerContext) {
                    return Builder(
                      builder: (final BuildContext innerContext) {
                        innerTranslator = innerContext.tr;
                        innerService = innerContext.translations;
                        return Container();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(innerTranslator, isNotNull);
      expect(innerService, isNotNull);
      expect(innerTranslator!.service, equals(service));
      expect(innerService, equals(service));
    });
  });
}
