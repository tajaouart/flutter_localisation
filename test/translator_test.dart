// test/translator_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'translator_test.mocks.dart';

@GenerateMocks(<Type>[TranslationService])
void main() {
  late MockTranslationService mockService;

  setUp(() {
    mockService = MockTranslationService();
    when(mockService.isLoggingEnabled).thenReturn(false);
  });

  Widget buildTestWidget(final Widget child) {
    return MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en', 'US'),
        Locale('es', 'ES'),
      ],
      locale: const Locale('en', 'US'),
      home: Scaffold(body: child),
    );
  }

  group('Translator - translate method', () {
    testWidgets('returns override when available',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'hello')).thenReturn('Hello {name}!');
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'hello': 'Hello {name}!',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'hello',
                <String, Object>{'name': 'Alice'},
                () => 'Fallback',
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, equals('Hello Alice!'));
      verify(mockService.getOverride('en', 'hello')).called(1);
    });

    testWidgets('returns fallback when no override',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'hello')).thenReturn(null);

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'hello',
                <String, Object>{},
                () => 'Generated Fallback',
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, equals('Generated Fallback'));
      verify(mockService.getOverride('en', 'hello')).called(1);
      verifyNever(mockService.getAllOverridesForLocale(any));
    });

    testWidgets('processes ICU plural messages in overrides',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'items')).thenReturn(
        '{count, plural, =0{No items} =1{One item} other{{count} items}}',
      );
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'items':
            '{count, plural, =0{No items} =1{One item} other{{count} items}}',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'items',
                <String, Object>{'count': 5},
                () => 'Fallback',
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, equals('5 items'));
    });

    testWidgets('processes ICU select messages in overrides',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'pronoun')).thenReturn(
        '{gender, select, male{He is} female{She is} other{They are}}',
      );
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'pronoun':
            '{gender, select, male{He is} female{She is} other{They are}}',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'pronoun',
                <String, dynamic>{'gender': 'female'},
                () => 'Fallback',
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, equals('She is'));
    });
  });

  group('Translator - caching behavior', () {
    testWidgets('caches ICUMessageProcessor for same locale',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'hello')).thenReturn('Hello {name}!');
      when(mockService.getOverride('en', 'goodbye'))
          .thenReturn('Goodbye {name}!');
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'hello': 'Hello {name}!',
        'goodbye': 'Goodbye {name}!',
      });

      String? result1;
      String? result2;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );

              // First translation
              result1 = translator.translate(
                'hello',
                <String, dynamic>{'name': 'Alice'},
                () => 'Fallback',
              );

              // Second translation with same translator instance
              result2 = translator.translate(
                'goodbye',
                <String, dynamic>{'name': 'Bob'},
                () => 'Fallback',
              );

              return const SizedBox();
            },
          ),
        ),
      );

      expect(result1, equals('Hello Alice!'));
      expect(result2, equals('Goodbye Bob!'));

      // getAllOverridesForLocale should only be called once due to caching
      verify(mockService.getAllOverridesForLocale('en')).called(1);
    });

    testWidgets('handles empty override gracefully',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'empty')).thenReturn('');
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'empty': '',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'empty',
                <String, dynamic>{},
                () => 'Fallback',
              );
              return const SizedBox();
            },
          ),
        ),
      );

      // Empty override returns empty string
      expect(result, equals(''));
    });
  });

  group('Translator - error handling', () {
    testWidgets('falls back to basic replacement on ICU error',
        (final WidgetTester tester) async {
      // Create an override with invalid ICU syntax that might cause errors
      when(mockService.getOverride('en', 'broken')).thenReturn('Hello {name}!');
      when(mockService.getAllOverridesForLocale('en'))
          .thenThrow(Exception('Test exception'));

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'broken',
                <String, dynamic>{'name': 'Alice'},
                () => 'Fallback',
              );
              return Container();
            },
          ),
        ),
      );

      // Should fall back to basic placeholder replacement
      expect(result, equals('Hello Alice!'));
    });

    testWidgets('handles null arguments gracefully',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'greeting'))
          .thenReturn('Hello {name}!');
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'greeting': 'Hello {name}!',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'greeting',
                <String, dynamic>{'name': null},
                () => 'Fallback',
              );
              return Container();
            },
          ),
        ),
      );

      expect(result, isNotNull);
    });
  });

  group('Translator - logging', () {
    testWidgets('logs when logging is enabled',
        (final WidgetTester tester) async {
      when(mockService.isLoggingEnabled).thenReturn(true);
      when(mockService.getOverride('en', 'hello')).thenReturn('Hello {name}!');
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'hello': 'Hello {name}!',
      });

      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              translator.translate(
                'hello',
                <String, dynamic>{'name': 'Alice'},
                () => 'Fallback',
              );
              return Container();
            },
          ),
        ),
      );

      verify(mockService.isLoggingEnabled).called(greaterThan(0));
    });

    testWidgets('does not log when logging is disabled',
        (final WidgetTester tester) async {
      when(mockService.isLoggingEnabled).thenReturn(false);
      when(mockService.getOverride('en', 'hello')).thenReturn('Hello {name}!');
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'hello': 'Hello {name}!',
      });

      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              translator.translate(
                'hello',
                <String, dynamic>{'name': 'Alice'},
                () => 'Fallback',
              );
              return Container();
            },
          ),
        ),
      );

      // Logging check happens but doesn't print
      verify(mockService.isLoggingEnabled).called(greaterThan(0));
    });
  });

  group('Translator - helper methods', () {
    testWidgets('refresh calls service.refresh',
        (final WidgetTester tester) async {
      when(mockService.refresh())
          .thenAnswer((final _) async => <dynamic, dynamic>{});

      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              translator.refresh();
              return Container();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      verify(mockService.refresh()).called(1);
    });

    testWidgets('cacheStatus returns service cache status',
        (final WidgetTester tester) async {
      when(mockService.getCacheStatus())
          .thenReturn(<String, int>{'en': 10, 'es': 5});

      Map<String, int>? status;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              status = translator.cacheStatus;
              return Container();
            },
          ),
        ),
      );

      expect(status, equals(<String, int>{'en': 10, 'es': 5}));
      verify(mockService.getCacheStatus()).called(1);
    });
  });

  group('Translator - complex scenarios', () {
    testWidgets('handles multiple placeholders in override',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'multi')).thenReturn(
        'Hello {firstName} {lastName}, you are {age} years old',
      );
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'multi': 'Hello {firstName} {lastName}, you are {age} years old',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'multi',
                <String, dynamic>{
                  'firstName': 'John',
                  'lastName': 'Doe',
                  'age': 30,
                },
                () => 'Fallback',
              );
              return Container();
            },
          ),
        ),
      );

      expect(result, equals('Hello John Doe, you are 30 years old'));
    });

    testWidgets('handles nested ICU messages',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'nested')).thenReturn(
        '{count, plural, =0{No {type} items} other{{count} {type} items}}',
      );
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'nested':
            '{count, plural, =0{No {type} items} other{{count} {type} items}}',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'nested',
                <String, dynamic>{
                  'count': 3,
                  'type': 'special',
                },
                () => 'Fallback',
              );
              return Container();
            },
          ),
        ),
      );

      expect(result, equals('3 special items'));
    });

    testWidgets('handles empty arguments map',
        (final WidgetTester tester) async {
      when(mockService.getOverride('en', 'simple'))
          .thenReturn('Simple message');
      when(mockService.getAllOverridesForLocale('en'))
          .thenReturn(<String, String>{
        'simple': 'Simple message',
      });

      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (final BuildContext context) {
              final Translator translator = Translator(
                context: context,
                service: mockService,
                generatedLocalizations: null,
              );
              result = translator.translate(
                'simple',
                <String, dynamic>{},
                () => 'Fallback',
              );
              return Container();
            },
          ),
        ),
      );

      expect(result, equals('Simple message'));
    });
  });
}
