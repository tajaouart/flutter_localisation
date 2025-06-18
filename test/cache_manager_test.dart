import 'dart:convert';

import 'package:flutter_localisation/src/api/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CacheManager', () {
    late SharedPreferences mockPrefs;
    late CacheManager cacheManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
      cacheManager = CacheManager(mockPrefs);
    });

    group('load', () {
      test('should load valid translations and versions from SharedPreferences',
          () async {
        final enData = {'hello': 'Hello', 'bye': 'Bye'};
        final esData = {'hello': 'Hola', 'bye': 'Adiós'};
        const enVersion = '2025-06-18T10:00:00Z';
        const esVersion = '2025-06-18T11:00:00Z';
        await mockPrefs.setString('flutter_trans_en', jsonEncode(enData));
        await mockPrefs.setString('flutter_version_en', enVersion);
        await mockPrefs.setString('flutter_trans_es', jsonEncode(esData));
        await mockPrefs.setString('flutter_version_es', esVersion);

        await cacheManager.load(['en', 'es']);

        expect(cacheManager.memoryCache['en'], equals(enData));
        expect(cacheManager.localVersions['en'], equals(enVersion));
        expect(cacheManager.memoryCache['es'], equals(esData));
        expect(cacheManager.localVersions['es'], equals(esVersion));
      });

      test(
          'should handle corrupted JSON gracefully by clearing the invalid locale',
          () async {
        final enData = {'hello': 'Hello'};
        const enVersion = '2025-06-18T09:00:00Z';
        await mockPrefs.setString('flutter_trans_en', jsonEncode(enData));
        await mockPrefs.setString('flutter_version_en', enVersion);
        await mockPrefs.setString('flutter_trans_fr', '{ "key": "value", }');
        await mockPrefs.setString('flutter_version_fr', 'v1');

        await cacheManager.load(['en', 'fr']);

        expect(cacheManager.memoryCache.containsKey('en'), isTrue);
        expect(cacheManager.localVersions['en'], enVersion);
        expect(cacheManager.memoryCache.containsKey('fr'), isFalse);
        expect(await mockPrefs.getString('flutter_trans_fr'), isNull);
      });

      test(
          'should default version to an empty string if version is missing in preferences',
          () async {
        await mockPrefs.setString(
            'flutter_trans_de', jsonEncode({'hallo': 'Hallo'}));
        await cacheManager.load(['de']);

        expect(cacheManager.localVersions['de'], equals(''));
      });
    });

    group('save', () {
      test('should update memory cache and persist data to SharedPreferences',
          () async {
        final translations = {'bonjour': 'Bonjour'};
        const locale = 'fr';
        const version = '2025-06-18T14:30:00Z';

        await cacheManager.save(locale, translations, version);

        expect(cacheManager.memoryCache[locale], equals(translations));
        expect(cacheManager.localVersions[locale], equals(version));

        final storedJson = mockPrefs.getString('flutter_trans_$locale');
        final storedVersion = mockPrefs.getString('flutter_version_$locale');

        expect(storedJson, isNotNull);
        expect(jsonDecode(storedJson!), equals(translations));
        expect(storedVersion, equals(version));
      });
    });

    group('clearLocale', () {
      test(
          'should remove data for a specific locale from memory and preferences',
          () async {
        await cacheManager.save('en', {'key': 'value'}, 'v1');

        await cacheManager.clearLocale('en');

        expect(cacheManager.memoryCache.containsKey('en'), isFalse);
        expect(cacheManager.localVersions.containsKey('en'), isFalse);
        expect(mockPrefs.containsKey('flutter_trans_en'), isFalse);
        expect(mockPrefs.containsKey('flutter_version_en'), isFalse);
      });
    });

    group('clearAll', () {
      test('should remove all data from memory and preferences', () async {
        await cacheManager.save('en', {'key1': 'value1'}, 'v1.0');
        await cacheManager.save('es', {'key2': 'value2'}, 'v2.0');

        await cacheManager.clearAll();

        expect(cacheManager.memoryCache.isEmpty, isTrue);
        expect(cacheManager.localVersions.isEmpty, isTrue);
        expect(mockPrefs.getKeys().isEmpty, isTrue);
      });
    });
  });
}
