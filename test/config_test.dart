// test/config_test.dart
import 'package:flutter_localisation/src/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranslationConfig - Default Constructor', () {
    test('creates config with all parameters', () {
      const TranslationConfig config = TranslationConfig(
        secretKey: 'sk_test_123',
        flavorName: 'premium',
        projectId: 42,
        supportedLocales: <String>['en', 'es', 'fr'],
        backgroundCheckInterval: Duration(minutes: 30),
      );

      expect(config.secretKey, equals('sk_test_123'));
      expect(config.flavorName, equals('premium'));
      expect(config.projectId, equals(42));
      expect(config.supportedLocales, equals(<String>['en', 'es', 'fr']));
      expect(config.enableLogging, isTrue);
      expect(
        config.backgroundCheckInterval,
        equals(const Duration(minutes: 30)),
      );
    });

    test('creates config with minimal parameters', () {
      const TranslationConfig config = TranslationConfig();

      expect(config.secretKey, isNull);
      expect(config.flavorName, isNull);
      expect(config.projectId, isNull);
      expect(config.supportedLocales, isNull);
      expect(config.enableLogging, isTrue); // Default value
      expect(config.backgroundCheckInterval, isNull);
    });

    test('creates config with partial parameters', () {
      const TranslationConfig config = TranslationConfig(
        secretKey: 'sk_test_456',
        enableLogging: false,
      );

      expect(config.secretKey, equals('sk_test_456'));
      expect(config.flavorName, isNull);
      expect(config.projectId, isNull);
      expect(config.supportedLocales, isNull);
      expect(config.enableLogging, isFalse);
      expect(config.backgroundCheckInterval, isNull);
    });

    test('enableLogging defaults to true', () {
      const TranslationConfig config = TranslationConfig();
      expect(config.enableLogging, isTrue);
    });
  });

  group('TranslationConfig - freeUser Factory', () {
    test('creates free user config with defaults', () {
      final TranslationConfig config = TranslationConfig.freeUser();

      expect(config.secretKey, isNull);
      expect(config.flavorName, isNull);
      expect(config.projectId, isNull);
      expect(config.supportedLocales, isNull);
      expect(config.enableLogging, isFalse); // Free user default
      expect(config.backgroundCheckInterval, isNull);
    });

    test('creates free user config with supported locales', () {
      final TranslationConfig config = TranslationConfig.freeUser(
        supportedLocales: <String>['en', 'es', 'de'],
      );

      expect(config.secretKey, isNull);
      expect(config.flavorName, isNull);
      expect(config.projectId, isNull);
      expect(config.supportedLocales, equals(<String>['en', 'es', 'de']));
      expect(config.enableLogging, isFalse);
      expect(config.backgroundCheckInterval, isNull);
    });

    test('creates free user config with logging enabled', () {
      final TranslationConfig config = TranslationConfig.freeUser(
        enableLogging: true,
      );

      expect(config.enableLogging, isTrue);
    });

    test('creates free user config with all parameters', () {
      final TranslationConfig config = TranslationConfig.freeUser(
        supportedLocales: <String>['en', 'fr'],
        enableLogging: true,
      );

      expect(config.supportedLocales, equals(<String>['en', 'fr']));
      expect(config.enableLogging, isTrue);
      expect(config.secretKey, isNull);
      expect(config.projectId, isNull);
    });
  });

  group('TranslationConfig - paidUser Factory', () {
    test('creates paid user config with required parameters', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_live_xyz',
        flavorName: 'enterprise',
        projectId: 100,
      );

      expect(config.secretKey, equals('sk_live_xyz'));
      expect(config.flavorName, equals('enterprise'));
      expect(config.projectId, equals(100));
      expect(config.enableLogging, isTrue); // Paid user default
      expect(config.supportedLocales, isNull);
      expect(config.backgroundCheckInterval, isNull);
    });

    test('creates paid user config with all parameters', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_live_abc',
        flavorName: 'premium',
        projectId: 200,
        apiBaseUrl: 'https://api.example.com',
        apiTimeout: const Duration(seconds: 30),
        supportedLocales: <String>['en', 'es', 'fr', 'de'],
        enableLogging: false,
        throwOnError: true,
        backgroundCheckInterval: const Duration(hours: 1),
      );

      expect(config.secretKey, equals('sk_live_abc'));
      expect(config.flavorName, equals('premium'));
      expect(config.projectId, equals(200));
      expect(config.supportedLocales, equals(<String>['en', 'es', 'fr', 'de']));
      expect(config.enableLogging, isFalse);
      expect(config.backgroundCheckInterval, equals(const Duration(hours: 1)));
    });

    test('creates paid user config with logging disabled', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
        enableLogging: false,
      );

      expect(config.enableLogging, isFalse);
    });

    test('creates paid user config with background check interval', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
        backgroundCheckInterval: const Duration(minutes: 15),
      );

      expect(
        config.backgroundCheckInterval,
        equals(const Duration(minutes: 15)),
      );
    });

    test('creates paid user config with custom supported locales', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
        supportedLocales: <String>['en', 'ja', 'ko', 'zh'],
      );

      expect(config.supportedLocales, equals(<String>['en', 'ja', 'ko', 'zh']));
    });
  });

  group('TranslationConfig - Comparison Tests', () {
    test('free user and paid user configs have different defaults', () {
      final TranslationConfig freeConfig = TranslationConfig.freeUser();
      final TranslationConfig paidConfig = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
      );

      // Free user: no API access
      expect(freeConfig.secretKey, isNull);
      expect(freeConfig.projectId, isNull);
      expect(freeConfig.flavorName, isNull);

      // Paid user: has API access
      expect(paidConfig.secretKey, isNotNull);
      expect(paidConfig.projectId, isNotNull);
      expect(paidConfig.flavorName, isNotNull);

      // Different logging defaults
      expect(freeConfig.enableLogging, isFalse);
      expect(paidConfig.enableLogging, isTrue);
    });

    test('can create equivalent configs using different constructors', () {
      const TranslationConfig config1 = TranslationConfig(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
        supportedLocales: <String>['en'],
        backgroundCheckInterval: Duration(minutes: 5),
      );

      final TranslationConfig config2 = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
        supportedLocales: const <String>['en'],
        backgroundCheckInterval: const Duration(minutes: 5),
      );

      expect(config1.secretKey, equals(config2.secretKey));
      expect(config1.flavorName, equals(config2.flavorName));
      expect(config1.projectId, equals(config2.projectId));
      expect(config1.supportedLocales, equals(config2.supportedLocales));
      expect(config1.enableLogging, equals(config2.enableLogging));
      expect(
        config1.backgroundCheckInterval,
        equals(config2.backgroundCheckInterval),
      );
    });
  });

  group('TranslationConfig - Edge Cases', () {
    test('handles empty supported locales list', () {
      final TranslationConfig config = TranslationConfig.freeUser(
        supportedLocales: <String>[],
      );

      expect(config.supportedLocales, isEmpty);
    });

    test('handles very long secret key', () {
      final String longKey = 'sk_${'x' * 1000}';
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: longKey,
        flavorName: 'test',
        projectId: 1,
      );

      expect(config.secretKey, equals(longKey));
      expect(config.secretKey!.length, equals(1003));
    });

    test('handles zero project ID', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 0,
      );

      expect(config.projectId, equals(0));
    });

    test('handles negative project ID', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: -1,
      );

      expect(config.projectId, equals(-1));
    });

    test('handles very short background check interval', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
        backgroundCheckInterval: const Duration(milliseconds: 1),
      );

      expect(
        config.backgroundCheckInterval,
        equals(const Duration(milliseconds: 1)),
      );
    });

    test('handles very long background check interval', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test',
        projectId: 1,
        backgroundCheckInterval: const Duration(days: 365),
      );

      expect(
        config.backgroundCheckInterval,
        equals(const Duration(days: 365)),
      );
    });

    test('handles special characters in flavor name', () {
      final TranslationConfig config = TranslationConfig.paidUser(
        secretKey: 'sk_test',
        flavorName: 'test-flavor_v2.0',
        projectId: 1,
      );

      expect(config.flavorName, equals('test-flavor_v2.0'));
    });

    test('handles many supported locales', () {
      final List<String> manyLocales =
          List<String>.generate(100, (final int i) => 'locale$i');
      final TranslationConfig config = TranslationConfig.freeUser(
        supportedLocales: manyLocales,
      );

      expect(config.supportedLocales, equals(manyLocales));
      expect(config.supportedLocales!.length, equals(100));
    });
  });

  group('TranslationConfig - Const Constructor', () {
    test('can be created as const when possible', () {
      const TranslationConfig config = TranslationConfig(
        enableLogging: false,
      );

      expect(config.enableLogging, isFalse);
      expect(config.secretKey, isNull);
    });

    test('const instances are identical when equal', () {
      const TranslationConfig config1 = TranslationConfig();
      const TranslationConfig config2 = TranslationConfig();

      expect(identical(config1, config2), isTrue);
    });
  });
}
