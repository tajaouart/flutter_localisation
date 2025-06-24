import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(final http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(<List<int>>[]),
      200,
    );
  }
}

void main() {
  group('TranslationService Embedded Timestamp Tests', () {
    late SharedPreferences prefs;
    late TranslationService service;
    late MockHttpClient mockHttpClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      mockHttpClient = MockHttpClient();
    });

    tearDown(() {
      service.dispose();
    });

    test('service initializes without embedded timestamp', () {
      // ARRANGE & ACT
      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en', 'fr']),
        httpClient: mockHttpClient,
      );

      // ASSERT
      expect(service.embeddedArbTimestamp, null);
    });

    test('service initializes with embedded timestamp', () {
      // ARRANGE
      const String timestamp = '2024-12-20T10:30:00.000Z';

      // ACT
      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en', 'fr']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: timestamp,
      );

      // ASSERT
      expect(service.embeddedArbTimestamp, timestamp);
    });

    test('initialization clears cache when embedded timestamp is newer',
        () async {
      // ARRANGE: Set old cache timestamp
      const String oldTimestamp = '2024-12-19T10:30:00Z';
      const String newTimestamp = '2024-12-20T10:30:00.000Z';

      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        oldTimestamp,
      );
      await prefs.setString('flutter_trans_en', '{"test_key": "test_value"}');
      await prefs.setString('flutter_version_en', 'v1.0');

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: newTimestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT: Cache should be cleared and timestamp updated
      expect(prefs.getString('flutter_trans_en'), null);
      expect(prefs.getString('flutter_version_en'), null);
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newTimestamp,
      );
      expect(service.getCacheStatus(), isEmpty);
    });

    test('clears cache for all locales when embedded timestamp is newer',
        () async {
      // ARRANGE: Set old cache timestamp and data for multiple locales
      const String oldTimestamp = '2024-12-19T10:30:00Z';
      const String newTimestamp = '2024-12-20T10:30:00.000Z';

      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        oldTimestamp,
      );

      // Setup multiple locales with translations
      await prefs.setString(
        'flutter_trans_en',
        '{"hello": "Hello", "goodbye": "Goodbye"}',
      );
      await prefs.setString('flutter_version_en', 'v1.0');
      await prefs.setString(
        'flutter_trans_fr',
        '{"hello": "Bonjour", "goodbye": "Au revoir"}',
      );
      await prefs.setString('flutter_version_fr', 'v1.1');
      await prefs.setString(
        'flutter_trans_es',
        '{"hello": "Hola", "goodbye": "Adiós"}',
      );
      await prefs.setString('flutter_version_es', 'v1.2');

      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en', 'fr', 'es'],
        ),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: newTimestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT: All locale data should be cleared
      expect(prefs.getString('flutter_trans_en'), null);
      expect(prefs.getString('flutter_version_en'), null);
      expect(prefs.getString('flutter_trans_fr'), null);
      expect(prefs.getString('flutter_version_fr'), null);
      expect(prefs.getString('flutter_trans_es'), null);
      expect(prefs.getString('flutter_version_es'), null);

      // Timestamp should be updated
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newTimestamp,
      );

      // Cache status should be empty for all locales
      expect(service.getCacheStatus(), isEmpty);

      // Verify specific overrides are cleared
      expect(service.getOverride('en', 'hello'), null);
      expect(service.getOverride('fr', 'hello'), null);
      expect(service.getOverride('es', 'hello'), null);
      expect(service.hasOverride('en', 'goodbye'), false);
      expect(service.hasOverride('fr', 'goodbye'), false);
      expect(service.hasOverride('es', 'goodbye'), false);
    });

    test('preserves cache for all locales when embedded timestamp is older',
        () async {
      // ARRANGE: Set a timestamp in the cache that is newer than the embedded one.
      const String newerCacheTimestamp = '2024-12-21T10:30:00.000Z';
      const String olderEmbeddedTimestamp = '2024-12-20T10:30:00.000Z';

      // Set the global cache timestamp to the newer date.
      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        newerCacheTimestamp,
      );

      // Setup multiple locales with their translation data.
      await prefs.setString('flutter_trans_en', '{"welcome": "Welcome"}');
      await prefs.setString('flutter_trans_fr', '{"welcome": "Bienvenue"}');

      // Initialize the service with the older embedded timestamp.
      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en', 'fr']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: olderEmbeddedTimestamp,
      );

      // ACT: Initialize the service. It should detect that the cache is newer.
      await service.initialize();

      // ASSERT: All locale data should be preserved because the cache is newer.

      // 1. The global timestamp in preferences should remain unchanged.
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newerCacheTimestamp,
      );

      // 2. The raw translation data in preferences should be preserved.
      expect(prefs.getString('flutter_trans_en'), isNotNull);
      expect(prefs.getString('flutter_trans_fr'), isNotNull);

      // 3. The service's internal cache should be successfully loaded from preferences.
      expect(service.getCacheStatus()['en'], 1);
      expect(service.getCacheStatus()['fr'], 1);

      // 4. Specific translations should be available in the service.
      expect(service.hasOverride('en', 'welcome'), isTrue);
      expect(service.getOverride('en', 'welcome'), 'Welcome');
      expect(service.hasOverride('fr', 'welcome'), isTrue);
      expect(service.getOverride('fr', 'welcome'), 'Bienvenue');
    });

    test('verifies both memory cache and SharedPreferences consistency',
        () async {
      // ARRANGE: Setup data in both memory and SharedPreferences
      const String oldTimestamp = '2024-12-19T10:30:00Z';
      const String newTimestamp = '2024-12-20T10:30:00.000Z';

      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        oldTimestamp,
      );
      await prefs.setString(
        'flutter_trans_en',
        '{"key1": "value1", "key2": "value2"}',
      );
      await prefs.setString('flutter_version_en', 'v1.0');
      await prefs.setString('flutter_trans_de', '{"schlüssel": "wert"}');
      await prefs.setString('flutter_version_de', 'v1.0');

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en', 'de']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: newTimestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT: Verify memory cache is cleared
      expect(service.getCacheStatus(), isEmpty);
      expect(service.getOverride('en', 'key1'), null);
      expect(service.getOverride('en', 'key2'), null);
      expect(service.getOverride('de', 'schlüssel'), null);
      expect(service.hasOverride('en', 'key1'), false);
      expect(service.hasOverride('de', 'schlüssel'), false);

      // ASSERT: Verify SharedPreferences is cleared
      expect(prefs.getString('flutter_trans_en'), null);
      expect(prefs.getString('flutter_version_en'), null);
      expect(prefs.getString('flutter_trans_de'), null);
      expect(prefs.getString('flutter_version_de'), null);

      // ASSERT: Verify timestamp is updated
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newTimestamp,
      );

      // ASSERT: Verify getAllOverridesForLocale returns empty
      expect(service.getAllOverridesForLocale('en'), isEmpty);
      expect(service.getAllOverridesForLocale('de'), isEmpty);
    });

    test('initialization preserves cache when timestamps are equal', () async {
      // ARRANGE: Set same timestamp
      const String sameTimestamp = '2024-12-20T10:30:00.000Z';

      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        sameTimestamp,
      );
      await prefs.setString('flutter_trans_en', '{"test_key": "test_value"}');
      await prefs.setString('flutter_version_en', 'v1.0');

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: sameTimestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT: Cache should be preserved
      expect(prefs.getString('flutter_trans_en'), isNotNull);
      expect(prefs.getString('flutter_version_en'), 'v1.0');
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        sameTimestamp,
      );
      expect(service.getCacheStatus()['en'], 1);
    });

    test('initialization sets timestamp when no cache exists', () async {
      // ARRANGE
      const String timestamp = '2024-12-20T10:30:00.000Z';

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: timestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        timestamp,
      );
    });

    test('initialization handles invalid timestamp gracefully', () async {
      // ARRANGE
      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        'invalid-timestamp',
      );

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: '2024-12-20T10:30:00.000Z',
      );

      // ACT & ASSERT: Should not throw
      expect(() => service.initialize(), returnsNormally);
    });

    test('multiple initializations do not cause issues', () async {
      // ARRANGE
      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: '2024-12-20T10:30:00.000Z',
      );

      // ACT: Initialize multiple times
      await service.initialize();
      await service.initialize();
      await service.initialize();

      // ASSERT: Should be stable
      expect(service.isReady, true);
      expect(service.embeddedArbTimestamp, '2024-12-20T10:30:00.000Z');
    });

    test('service works correctly without any configuration', () async {
      // ARRANGE & ACT
      service = TranslationService(httpClient: mockHttpClient);
      await service.initialize();

      // ASSERT
      expect(service.isReady, true);
      expect(service.embeddedArbTimestamp, null);
      expect(service.getCacheStatus(), isEmpty);
    });
  });

  group('Integration Tests', () {
    late TranslationService service;
    late MockHttpClient mockHttpClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockHttpClient = MockHttpClient();
    });

    tearDown(() {
      service.dispose();
    });

    test('complete workflow: app update scenario with multiple locales',
        () async {
      // SIMULATE: App with old translations for multiple locales
      const String oldEmbeddedTimestamp = '2024-12-19T10:00:00Z';

      // Setup initial cache data in SharedPreferences FIRST
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'flutter_trans_en',
        '{"old_key": "old_value", "common": "english"}',
      );
      await prefs.setString('flutter_version_en', 'v1.0');
      await prefs.setString(
        'flutter_trans_fr',
        '{"old_key": "ancienne_valeur", "common": "français"}',
      );
      await prefs.setString('flutter_version_fr', 'v1.0');
      await prefs.setString(
        'flutter_trans_de',
        '{"old_key": "alter_wert", "common": "deutsch"}',
      );
      await prefs.setString('flutter_version_de', 'v1.0');

      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en', 'fr', 'de'],
        ),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: oldEmbeddedTimestamp,
      );

      await service.initialize();

      // Verify data exists before app update
      expect(service.getCacheStatus()['en'], 2);
      expect(service.getCacheStatus()['fr'], 2);
      expect(service.getCacheStatus()['de'], 2);
      expect(service.getOverride('en', 'common'), 'english');
      expect(service.getOverride('fr', 'common'), 'français');
      expect(service.getOverride('de', 'common'), 'deutsch');

      service.dispose();

      // SIMULATE: App update with new translations
      const String newEmbeddedTimestamp = '2024-12-20T15:00:00.000Z';

      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en', 'fr', 'de'],
        ),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: newEmbeddedTimestamp,
      );

      // ACT: Initialize after "app update"
      await service.initialize();

      // ASSERT: All locale caches should be cleared
      expect(service.getCacheStatus(), isEmpty);
      expect(prefs.getString('flutter_trans_en'), null);
      expect(prefs.getString('flutter_trans_fr'), null);
      expect(prefs.getString('flutter_trans_de'), null);
      expect(prefs.getString('flutter_version_en'), null);
      expect(prefs.getString('flutter_version_fr'), null);
      expect(prefs.getString('flutter_version_de'), null);
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newEmbeddedTimestamp,
      );

      // ASSERT: Verify specific translations are cleared
      expect(service.getOverride('en', 'old_key'), null);
      expect(service.getOverride('fr', 'old_key'), null);
      expect(service.getOverride('de', 'old_key'), null);
      expect(service.getOverride('en', 'common'), null);
      expect(service.getOverride('fr', 'common'), null);
      expect(service.getOverride('de', 'common'), null);

      // ASSERT: Verify hasOverride returns false
      expect(service.hasOverride('en', 'old_key'), false);
      expect(service.hasOverride('fr', 'old_key'), false);
      expect(service.hasOverride('de', 'old_key'), false);

      // ASSERT: Verify getAllOverridesForLocale returns empty for all locales
      expect(service.getAllOverridesForLocale('en'), isEmpty);
      expect(service.getAllOverridesForLocale('fr'), isEmpty);
      expect(service.getAllOverridesForLocale('de'), isEmpty);
    });

    test('partial locale data survives when timestamp is older', () async {
      // ARRANGE: Setup cache with mixed locale data
      const String newerCacheTimestamp = '2024-12-21T10:00:00Z';
      const String olderEmbeddedTimestamp = '2024-12-20T10:00:00.000Z';

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        newerCacheTimestamp,
      );

      // Setup only some locales with data (simulating partial cache)
      await prefs.setString('flutter_trans_en', '{"key1": "value1"}');
      await prefs.setString('flutter_version_en', 'v1.0');
      await prefs.setString('flutter_trans_es', '{"clave1": "valor1"}');
      await prefs.setString('flutter_version_es', 'v1.0');
      // Note: no French data

      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en', 'fr', 'es'],
        ),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: olderEmbeddedTimestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT: Existing data should be preserved
      expect(service.getCacheStatus()['en'], 1);
      expect(service.getCacheStatus()['es'], 1);
      expect(service.getCacheStatus().containsKey('fr'), false);
      expect(service.getOverride('en', 'key1'), 'value1');
      expect(service.getOverride('es', 'clave1'), 'valor1');
      expect(service.getOverride('fr', 'anything'), null);
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newerCacheTimestamp,
      );
    });
  });
}
