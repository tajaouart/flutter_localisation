import 'dart:convert';

import 'package:flutter_localisation/src/api/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CacheManager', () {
    // These will be re-initialized for each test in setUp()
    late SharedPreferences mockPrefs;
    late CacheManager cacheManager;

    setUp(() async {
      // Before each test, clear out any previous mock data and create
      // fresh instances of our mock preferences and the cache manager.
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
      cacheManager = CacheManager(mockPrefs);
    });

    group('load', () {
      test('should load valid translations and versions from SharedPreferences',
          () async {
        // Arrange: Pre-populate the mock preferences with valid data.
        final enData = {'hello': 'Hello', 'bye': 'Bye'};
        final esData = {'hello': 'Hola', 'bye': 'Adiós'};
        await mockPrefs.setString('flutter_trans_en', jsonEncode(enData));
        await mockPrefs.setInt('flutter_version_en', 10);
        await mockPrefs.setString('flutter_trans_es', jsonEncode(esData));
        await mockPrefs.setInt('flutter_version_es', 20);

        // Act: Call the load method.
        await cacheManager.load(['en', 'es']);

        // Assert: Check that the in-memory cache was populated correctly.
        expect(cacheManager.memoryCache['en'], equals(enData));
        expect(cacheManager.localVersions['en'], equals(10));
        expect(cacheManager.memoryCache['es'], equals(esData));
        expect(cacheManager.localVersions['es'], equals(20));
      });

      test(
          'should handle corrupted JSON gracefully by clearing the invalid locale',
          () async {
        // Arrange: Pre-populate with one valid and one corrupted entry.
        final enData = {'hello': 'Hello'};
        await mockPrefs.setString('flutter_trans_en', jsonEncode(enData));
        await mockPrefs.setInt('flutter_version_en', 5);
        await mockPrefs.setString(
            'flutter_trans_fr', '{ "key": "value", }'); // Invalid JSON
        await mockPrefs.setInt('flutter_version_fr', 1);

        // Act: Load both locales.
        await cacheManager.load(['en', 'fr']);

        // Assert: The valid locale is loaded, and the corrupt one is cleared.
        expect(cacheManager.memoryCache.containsKey('en'), isTrue);
        expect(cacheManager.localVersions['en'], 5);

        expect(cacheManager.memoryCache.containsKey('fr'), isFalse,
            reason: "Corrupted locale should be removed from memory cache.");
        expect(await mockPrefs.getString('flutter_trans_fr'), isNull,
            reason: "Corrupted locale should be cleared from preferences.");
      });

      test('should default version to 0 if version is missing in preferences',
          () async {
        // Arrange: Save translations but not a version number.
        await mockPrefs.setString(
            'flutter_trans_de', jsonEncode({'hallo': 'Hallo'}));

        // Act
        await cacheManager.load(['de']);

        // Assert
        expect(cacheManager.localVersions['de'], equals(0));
      });
    });

    group('save', () {
      test('should update memory cache and persist data to SharedPreferences',
          () async {
        // Arrange
        final translations = {'bonjour': 'Bonjour'};
        const locale = 'fr';
        const version = 15;

        // Act: Save the new data.
        await cacheManager.save(locale, translations, version);

        // Assert: Check both the in-memory cache and the mock preferences.
        // Check memory
        expect(cacheManager.memoryCache[locale], equals(translations));
        expect(cacheManager.localVersions[locale], equals(version));

        // Check persistent storage (SharedPreferences)
        final storedJson = mockPrefs.getString('flutter_trans_$locale');
        final storedVersion = mockPrefs.getInt('flutter_version_$locale');
        expect(storedJson, isNotNull);
        expect(jsonDecode(storedJson!), equals(translations));
        expect(storedVersion, equals(version));
      });
    });

    group('clearLocale', () {
      test(
          'should remove data for a specific locale from memory and preferences',
          () async {
        // Arrange: Save some initial data.
        await cacheManager.save('en', {'key': 'value'}, 1);

        // Act: Clear the locale.
        await cacheManager.clearLocale('en');

        // Assert: Check that data is gone from both caches.
        expect(cacheManager.memoryCache.containsKey('en'), isFalse);
        expect(cacheManager.localVersions.containsKey('en'), isFalse);
        expect(mockPrefs.containsKey('flutter_trans_en'), isFalse);
        expect(mockPrefs.containsKey('flutter_version_en'), isFalse);
      });
    });

    group('clearAll', () {
      test('should remove all data from memory and preferences', () async {
        // Arrange: Save data for multiple locales.
        await cacheManager.save('en', {'key1': 'value1'}, 1);
        await cacheManager.save('es', {'key2': 'value2'}, 2);

        // Act: Call clearAll.
        await cacheManager.clearAll();

        // Assert: Check that everything is empty.
        expect(cacheManager.memoryCache.isEmpty, isTrue);
        expect(cacheManager.localVersions.isEmpty, isTrue);
        expect(mockPrefs.getKeys().isEmpty, isTrue,
            reason: "SharedPreferences should be empty after clearAll.");
      });
    });
  });
}
