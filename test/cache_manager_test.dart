import 'dart:convert';

import 'package:flutter_localisation/src/api/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CacheManager', () {
    late SharedPreferences mockPrefs;
    late CacheManager cacheManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockPrefs = await SharedPreferences.getInstance();
      cacheManager = CacheManager(mockPrefs);
    });

    group('load', () {
      test('should load valid translations and versions from SharedPreferences',
          () async {
        final Map<String, String> enData = <String, String>{
          'hello': 'Hello',
          'bye': 'Bye',
        };
        final Map<String, String> esData = <String, String>{
          'hello': 'Hola',
          'bye': 'Adiós',
        };
        const String enVersion = '2025-06-18T10:00:00Z';
        const String esVersion = '2025-06-18T11:00:00Z';
        await mockPrefs.setString('flutter_trans_en', jsonEncode(enData));
        await mockPrefs.setString('flutter_version_en', enVersion);
        await mockPrefs.setString('flutter_trans_es', jsonEncode(esData));
        await mockPrefs.setString('flutter_version_es', esVersion);

        await cacheManager.load(<String>['en', 'es']);

        expect(cacheManager.memoryCache['en'], equals(enData));
        expect(cacheManager.localTimestamps['en'], equals(enVersion));
        expect(cacheManager.memoryCache['es'], equals(esData));
        expect(cacheManager.localTimestamps['es'], equals(esVersion));
      });

      test(
          'should handle corrupted JSON gracefully by clearing the invalid locale',
          () async {
        final Map<String, String> enData = <String, String>{'hello': 'Hello'};
        const String enVersion = '2025-06-18T09:00:00Z';
        await mockPrefs.setString('flutter_trans_en', jsonEncode(enData));
        await mockPrefs.setString('flutter_version_en', enVersion);
        await mockPrefs.setString('flutter_trans_fr', '{ "key": "value", }');
        await mockPrefs.setString('flutter_version_fr', 'v1');

        await cacheManager.load(<String>['en', 'fr']);

        expect(cacheManager.memoryCache.containsKey('en'), isTrue);
        expect(cacheManager.localTimestamps['en'], enVersion);
        expect(cacheManager.memoryCache.containsKey('fr'), isFalse);
        expect(await mockPrefs.getString('flutter_trans_fr'), isNull);
      });

      test(
          'should default version to an empty string if version is missing in preferences',
          () async {
        await mockPrefs.setString(
          'flutter_trans_de',
          jsonEncode(<String, String>{'hallo': 'Hallo'}),
        );
        await cacheManager.load(<String>['de']);

        expect(cacheManager.localTimestamps['de'], equals(''));
      });

      // NEW: Test loading with global timestamp
      test('should load global cache timestamp during load', () async {
        const String globalTimestamp = '2025-06-24T10:00:00Z';
        await mockPrefs.setString(
          'flutter_localisation_cache_timestamp',
          globalTimestamp,
        );

        await cacheManager.load(<String>['en']);

        expect(cacheManager.lastCacheUpdateTime, equals(globalTimestamp));
      });

      // NEW: Test empty locale list
      test('should handle empty locale list gracefully', () async {
        await cacheManager.load(<String>[]);

        expect(cacheManager.memoryCache.isEmpty, isTrue);
        expect(cacheManager.localTimestamps.isEmpty, isTrue);
      });

      // NEW: Test loading non-existent locale
      test('should handle loading non-existent locale gracefully', () async {
        await cacheManager.load(<String>['xx']);

        expect(cacheManager.memoryCache.containsKey('xx'), isFalse);
        expect(cacheManager.localTimestamps.containsKey('xx'), isFalse);
      });
    });

    group('save', () {
      test('should update memory cache and persist data to SharedPreferences',
          () async {
        final Map<String, String> translations = <String, String>{
          'bonjour': 'Bonjour',
        };
        const String locale = 'fr';
        const String version = '2025-06-18T14:30:00Z';

        await cacheManager.save(locale, translations, version);

        expect(cacheManager.memoryCache[locale], equals(translations));
        expect(cacheManager.localTimestamps[locale], equals(version));

        final String? storedJson = mockPrefs.getString('flutter_trans_$locale');
        final String? storedVersion =
            mockPrefs.getString('flutter_version_$locale');

        expect(storedJson, isNotNull);
        expect(jsonDecode(storedJson!), equals(translations));
        expect(storedVersion, equals(version));
      });

      // NEW: Test saving updates global timestamp
      test('should update global cache timestamp when saving', () async {
        const String timestamp = '2025-06-24T15:00:00Z';
        await cacheManager.save(
          'en',
          <String, String>{'key': 'value'},
          timestamp,
        );

        expect(cacheManager.lastCacheUpdateTime, equals(timestamp));
        expect(
          mockPrefs.getString('flutter_localisation_cache_timestamp'),
          equals(timestamp),
        );
      });

      // NEW: Test overwriting existing locale data
      test('should overwrite existing locale data', () async {
        await cacheManager.save('en', <String, String>{'old': 'data'}, 'v1');
        await cacheManager.save('en', <String, String>{'new': 'data'}, 'v2');

        expect(
          cacheManager.memoryCache['en'],
          equals(<String, String>{'new': 'data'}),
        );
        expect(cacheManager.localTimestamps['en'], equals('v2'));
      });

      // NEW: Test saving empty translations
      test('should handle empty translations map', () async {
        await cacheManager.save(
          'en',
          <String, String>{},
          '2025-06-24T10:00:00Z',
        );

        expect(cacheManager.memoryCache['en'], isEmpty);
        expect(
          cacheManager.localTimestamps['en'],
          equals('2025-06-24T10:00:00Z'),
        );
      });

      // NEW: Test saving with special characters
      test('should handle special characters in translations', () async {
        final Map<String, String> specialTranslations = <String, String>{
          'special': 'Test with "quotes" and \'apostrophes\'',
          'unicode': 'Test with émojis 🎉 and ñ',
          'newlines': 'Test\nwith\nnewlines',
        };

        await cacheManager.save('en', specialTranslations, 'v1');

        final String? stored = mockPrefs.getString('flutter_trans_en');
        expect(jsonDecode(stored!), equals(specialTranslations));
      });
    });

    group('clearLocale', () {
      test(
          'should remove data for a specific locale from memory and preferences',
          () async {
        await cacheManager.save('en', <String, String>{'key': 'value'}, 'v1');

        await cacheManager.clearLocale('en');

        expect(cacheManager.memoryCache.containsKey('en'), isFalse);
        expect(cacheManager.localTimestamps.containsKey('en'), isFalse);
        expect(mockPrefs.containsKey('flutter_trans_en'), isFalse);
        expect(mockPrefs.containsKey('flutter_version_en'), isFalse);
      });

      // NEW: Test clearing non-existent locale
      test('should handle clearing non-existent locale gracefully', () async {
        await cacheManager.clearLocale('xx');

        expect(cacheManager.memoryCache.containsKey('xx'), isFalse);
        expect(cacheManager.localTimestamps.containsKey('xx'), isFalse);
      });

      // NEW: Test that clearLocale doesn't affect other locales
      test('should not affect other locales when clearing one', () async {
        await cacheManager.save('en', <String, String>{'en': 'English'}, 'v1');
        await cacheManager.save('fr', <String, String>{'fr': 'French'}, 'v2');

        await cacheManager.clearLocale('en');

        expect(cacheManager.memoryCache.containsKey('en'), isFalse);
        expect(cacheManager.memoryCache.containsKey('fr'), isTrue);
        expect(cacheManager.localTimestamps['fr'], equals('v2'));
      });

      // NEW: Test that clearLocale clears lastCacheUpdateTime
      test('should clear lastCacheUpdateTime when clearing locale', () async {
        await cacheManager.save(
          'en',
          <String, String>{'key': 'value'},
          '2025-06-24T10:00:00Z',
        );
        expect(cacheManager.lastCacheUpdateTime, isNotEmpty);

        await cacheManager.clearLocale('en');

        expect(cacheManager.lastCacheUpdateTime, isEmpty);
      });
    });

    group('clearAll', () {
      test('should remove per-locale data but preserve the global timestamp',
          () async {
        await cacheManager.save(
          'en',
          <String, String>{'key1': 'value1'},
          'v1.0',
        );
        await cacheManager.save(
          'fr',
          <String, String>{'key2': 'value2'},
          'v2.0',
        );
        await cacheManager.setLastCacheUpdateTime('2025-06-24T10:00:00Z');

        await cacheManager.clearAll();

        expect(cacheManager.memoryCache.isEmpty, isTrue);
        expect(cacheManager.localTimestamps.isEmpty, isTrue);

        final Set<String> remainingKeys = mockPrefs.getKeys();
        expect(remainingKeys.length, 1);
        expect(remainingKeys.first, 'flutter_localisation_cache_timestamp');
      });

      // NEW: Test clearAll with no data
      test('should handle clearAll when no data exists', () async {
        await cacheManager.clearAll();

        expect(cacheManager.memoryCache.isEmpty, isTrue);
        expect(cacheManager.localTimestamps.isEmpty, isTrue);
      });

      // NEW: Test clearAll clears lastCacheUpdateTime in memory
      test('should clear lastCacheUpdateTime in memory', () async {
        await cacheManager.save(
          'en',
          <String, String>{'key': 'value'},
          '2025-06-24T10:00:00Z',
        );
        expect(cacheManager.lastCacheUpdateTime, isNotEmpty);

        await cacheManager.clearAll();

        expect(cacheManager.lastCacheUpdateTime, isEmpty);
      });
    });

    group('timestamp management', () {
      // NEW: Test timestamp getter
      test('should return correct lastCacheUpdateTime', () async {
        const String timestamp = '2025-06-24T12:00:00Z';
        await cacheManager.setLastCacheUpdateTime(timestamp);

        expect(cacheManager.lastCacheUpdateTime, equals(timestamp));
      });

      // NEW: Test setting and getting timestamp persistence
      test('should persist and retrieve global timestamp correctly', () async {
        const String timestamp = '2025-06-24T14:00:00Z';
        await cacheManager.setLastCacheUpdateTime(timestamp);

        // Create new instance to test persistence
        final CacheManager newCacheManager = CacheManager(mockPrefs);
        await newCacheManager.load(<String>[]);

        expect(newCacheManager.lastCacheUpdateTime, equals(timestamp));
      });

      // NEW: Test timestamp updates when saving different locales
      test('should update timestamp when saving any locale', () async {
        const String timestamp1 = '2025-06-24T10:00:00Z';
        const String timestamp2 = '2025-06-24T11:00:00Z';

        await cacheManager.save(
          'en',
          <String, String>{'key': 'value'},
          timestamp1,
        );
        expect(cacheManager.lastCacheUpdateTime, equals(timestamp1));

        await cacheManager.save(
          'fr',
          <String, String>{'key': 'value'},
          timestamp2,
        );
        expect(cacheManager.lastCacheUpdateTime, equals(timestamp2));
      });
    });

    group('edge cases and error handling', () {
      // NEW: Test concurrent operations
      test('should handle concurrent save operations', () async {
        final List<Future<dynamic>> futures = <Future<dynamic>>[];

        for (int i = 0; i < 10; i++) {
          futures.add(
            cacheManager.save(
              'locale$i',
              <String, String>{'key': 'value$i'},
              'v$i',
            ),
          );
        }

        await Future.wait(futures);

        expect(cacheManager.memoryCache.length, equals(10));
        expect(cacheManager.localTimestamps.length, equals(10));
      });

      // NEW: Test very large translation sets
      test('should handle large translation sets', () async {
        final Map<String, String> largeTranslations = <String, String>{};
        for (int i = 0; i < 1000; i++) {
          largeTranslations['key_$i'] = 'value_$i';
        }

        await cacheManager.save('en', largeTranslations, 'v1');

        expect(cacheManager.memoryCache['en']!.length, equals(1000));
      });

      // NEW: Test locale name edge cases
      test('should handle various locale name formats', () async {
        final List<String> locales = <String>[
          'en',
          'en-US',
          'zh-Hans',
          'pt-BR',
          'es-419',
        ];

        for (final String locale in locales) {
          await cacheManager.save(
            locale,
            <String, String>{'key': locale},
            'v1',
          );
        }

        for (final String locale in locales) {
          expect(
            cacheManager.memoryCache[locale],
            equals(<String, String>{'key': locale}),
          );
        }
      });
    });
  });
}
