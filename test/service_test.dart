import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_localisation/src/api/api_repository.dart';
import 'package:flutter_localisation/src/api/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart'; // We'll use mockito for the repository
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks(<Type>[ApiRepository, http.Client])
import 'service_test.mocks.dart';

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

    test('initialization preserves cache when embedded timestamp is older',
        () async {
      // ARRANGE: Set newer cache timestamp
      const String newerTimestamp = '2024-12-21T10:30:00Z';
      const String olderTimestamp = '2024-12-20T10:30:00.000Z';

      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        newerTimestamp,
      );
      await prefs.setString('flutter_trans_en', '{"test_key": "test_value"}');
      await prefs.setString('flutter_version_en', 'v1.0');

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: olderTimestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT: Cache should be preserved
      expect(prefs.getString('flutter_trans_en'), isNotNull);
      expect(prefs.getString('flutter_version_en'), 'v1.0');
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newerTimestamp,
      );
      expect(service.getCacheStatus()['en'], 1);
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

    test('complete workflow: app update scenario', () async {
      // SIMULATE: App with old translations
      const String oldEmbeddedTimestamp = '2024-12-19T10:00:00Z';

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: oldEmbeddedTimestamp,
      );

      await service.initialize();

      // Simulate some cached overrides
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter_trans_en', '{"old_key": "old_value"}');
      await prefs.setString('flutter_version_en', 'v1.0');

      service.dispose();

      // SIMULATE: App update with new translations
      const String newEmbeddedTimestamp = '2024-12-20T15:00:00.000Z';

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: newEmbeddedTimestamp,
      );

      // ACT: Initialize after "app update"
      await service.initialize();

      // ASSERT: Old cache should be cleared
      expect(service.getCacheStatus(), isEmpty);
      expect(prefs.getString('flutter_trans_en'), null);
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newEmbeddedTimestamp,
      );
    });

    // Add these tests to your existing translator_test.dart

    test('clears cache for all locales when embedded timestamp is newer',
        () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // ARRANGE: Setup data for multiple locales BEFORE initializing service
      const String oldTimestamp = '2024-12-19T10:30:00Z';
      const String newTimestamp = '2024-12-20T10:30:00.000Z';

      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        oldTimestamp,
      );
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
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // ARRANGE: Set newer cache timestamp
      const String newerTimestamp = '2024-12-21T10:30:00Z';
      const String olderTimestamp = '2024-12-20T10:30:00.000Z';

      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        newerTimestamp,
      );
      await prefs.setString('flutter_trans_en', '{"welcome": "Welcome"}');
      await prefs.setString('flutter_version_en', 'v2.0');
      await prefs.setString('flutter_trans_fr', '{"welcome": "Bienvenue"}');
      await prefs.setString('flutter_version_fr', 'v2.1');

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en', 'fr']),
        httpClient: mockHttpClient,
        embeddedArbTimestamp: olderTimestamp,
      );

      // ACT
      await service.initialize();

      // ASSERT: All locale data should be preserved
      expect(prefs.getString('flutter_trans_en'), isNotNull);
      expect(prefs.getString('flutter_version_en'), 'v2.0');
      expect(prefs.getString('flutter_trans_fr'), isNotNull);
      expect(prefs.getString('flutter_version_fr'), 'v2.1');

      // Cache should contain data for both locales
      expect(service.getCacheStatus()['en'], 1);
      expect(service.getCacheStatus()['fr'], 1);

      // Verify specific overrides are preserved
      expect(service.getOverride('en', 'welcome'), 'Welcome');
      expect(service.getOverride('fr', 'welcome'), 'Bienvenue');
      expect(service.hasOverride('en', 'welcome'), true);
      expect(service.hasOverride('fr', 'welcome'), true);
    });

    // The test is renamed to accurately describe what the code ACTUALLY does.
    test('clearCache clears locale data and the global timestamp', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // ARRANGE
      const String initialTimestamp = '2025-01-01T00:00:00.000Z';
      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        initialTimestamp,
      );
      await prefs.setString('flutter_trans_en', '{"test": "value"}');
      await prefs.setString('flutter_trans_fr', '{"test": "valeur"}');

      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en', 'fr']),
        httpClient: mockHttpClient,
      );
      await service.initialize();

      // ACT
      await service.clearCache();

      // ASSERT: Verify all translation data is cleared
      expect(prefs.getString('flutter_trans_en'), isNull);
      expect(prefs.getString('flutter_trans_fr'), isNull);
      expect(service.getCacheStatus(), isEmpty);
      expect(service.hasOverride('en', 'test'), false);

      final String? timestampAfterClear =
          prefs.getString('flutter_localisation_cache_timestamp');
      expect(timestampAfterClear, '');
    });

    // Replace your Integration Tests group with this enhanced version:
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

        // Verify specific translations are cleared
        expect(service.getOverride('en', 'old_key'), null);
        expect(service.getOverride('fr', 'old_key'), null);
        expect(service.getOverride('de', 'old_key'), null);
        expect(service.getOverride('en', 'common'), null);
        expect(service.getOverride('fr', 'common'), null);
        expect(service.getOverride('de', 'common'), null);

        // Verify hasOverride returns false
        expect(service.hasOverride('en', 'old_key'), false);
        expect(service.hasOverride('fr', 'old_key'), false);
        expect(service.hasOverride('de', 'old_key'), false);

        // Verify getAllOverridesForLocale returns empty for all locales
        expect(service.getAllOverridesForLocale('en'), isEmpty);
        expect(service.getAllOverridesForLocale('fr'), isEmpty);
        expect(service.getAllOverridesForLocale('de'), isEmpty);
      });

      test('partial locale clearing: only some locales have cached data',
          () async {
        // ARRANGE: Setup cache with only some locales having data
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
        expect(service.getAllOverridesForLocale('fr'), isEmpty);
        expect(
          prefs.getString('flutter_localisation_cache_timestamp'),
          newerCacheTimestamp,
        );
      });
    });
  });

  group('CacheManager Detailed Interaction Tests', () {
    late SharedPreferences prefs;
    late CacheManager cacheManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      cacheManager = CacheManager(prefs);
    });

    test('clearLocale only removes data for the specified locale', () async {
      // ARRANGE: Save data for three locales
      await cacheManager.save('en', <String, String>{'hello': 'Hello'}, 'v1');
      await cacheManager.save('fr', <String, String>{'hello': 'Bonjour'}, 'v1');
      await cacheManager.save('es', <String, String>{'hello': 'Hola'}, 'v1');

      // ACT: Clear only the French locale
      await cacheManager.clearLocale('fr');

      // ASSERT: Check that 'en' and 'es' data still exist
      expect(cacheManager.memoryCache.containsKey('en'), isTrue);
      expect(cacheManager.memoryCache.containsKey('es'), isTrue);
      expect(prefs.getString('flutter_trans_en'), isNotNull);
      expect(prefs.getString('flutter_trans_es'), isNotNull);

      // Assert that 'fr' data is gone
      expect(cacheManager.memoryCache.containsKey('fr'), isFalse);
      expect(prefs.getString('flutter_trans_fr'), isNull);
    });

    test('clearAll removes ALL locale data and the global timestamp', () async {
      // ARRANGE: Save data and a global timestamp
      await cacheManager.save('en', <String, String>{'hello': 'Hello'}, 'v1');
      await cacheManager.setLastCacheUpdateTime('2025-01-01T12:00:00Z');

      // ACT: Clear everything
      await cacheManager.clearAll();

      // ASSERT
      expect(cacheManager.memoryCache.isEmpty, isTrue);
      expect(prefs.getString('flutter_trans_en'), isNull);
      expect(prefs.getString('flutter_localisation_cache_timestamp'), isEmpty);
    });
  });

  group('Update Fetching Edge Cases', () {
    late TranslationService service;
    late MockApiRepository mockRepository; // Use the generated mock

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockRepository = MockApiRepository();

      // Create the service, injecting the MOCK repository
      service = TranslationService(
        config: const TranslationConfig(supportedLocales: <String>['en']),
        repository: mockRepository,
      );

      // We must always initialize the service
      await service.initialize();
    });

    test('handles API response with no new updates gracefully', () async {
      // ARRANGE: Mock the repository to return a "no updates" response
      when(mockRepository.fetchUpdates(any)).thenAnswer(
        (final _) async => <String, dynamic>{
          'has_updates': false,
        },
      );

      await service.refresh();
      expect(service.getCacheStatus(), isEmpty);
    });

    test('handles API response with empty translations map', () async {
      // ARRANGE: Mock the repository to return an empty translations payload
      when(mockRepository.fetchUpdates(any)).thenAnswer(
        (final _) async => <String, dynamic>{
          'has_updates': true,
          'last_modified': '2025-01-01T12:00:00Z',
          'translations': <dynamic, dynamic>{}, // Empty map
        },
      );

      // ACT
      await service.refresh();

      expect(service.getCacheStatus(), isEmpty);
    });
  });

  group('Timestamp Overwriting Logic Tests', () {
    late SharedPreferences prefs;
    late MockApiRepository mockRepository; // Use a mock for the API
    late TranslationService service;

    setUp(() async {
      // Ensure a clean state for each test
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      mockRepository = MockApiRepository();
    });

    tearDown(() {
      service.dispose();
    });

    test(
        'a successful API fetch updates both translations and the global timestamp',
        () async {
      // ARRANGE: Start with an empty cache and an old timestamp
      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        '2025-01-01T00:00:00Z',
      );

      // Mock the API to return a new update
      const String apiTimestamp = '2025-01-02T12:00:00Z';
      when(mockRepository.fetchUpdates(any)).thenAnswer(
        (final _) async => <String, dynamic>{
          'has_updates': true,
          'last_modified': apiTimestamp,
          'translations': <String, Map<String, String>>{
            'en': <String, String>{'hello': 'Hello from API'},
          },
        },
      );

      // --- THIS IS THE FIX ---
      // 1. Provide a projectId and secretKey so `isApiConfigured` returns true.
      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en'],
          projectId: 999,
          secretKey: 'test-secret-key',
        ),
        repository: mockRepository,
      );

      await service.initialize(fetchUpdatesOnStart: false);

      await service.refresh();

      expect(service.getOverride('en', 'hello'), 'Hello from API');
      expect(prefs.getString('flutter_trans_en'), contains('Hello from API'));
      expect(prefs.getString('flutter_version_en'), apiTimestamp);
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        apiTimestamp,
      );
    });

    test('an API fetch after an app update uses the correct new timestamp',
        () async {
      const String oldCacheTimestamp = '2025-02-01T00:00:00Z';
      await prefs.setString(
        'flutter_localisation_cache_timestamp',
        oldCacheTimestamp,
      );
      await prefs.setString('flutter_trans_en', '{"key": "old value"}');

      const String newerEmbeddedTimestamp = '2025-02-02T00:00:00Z';

      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en'],
          projectId: 99,
          secretKey: 'test-secret-key',
        ),
        repository: mockRepository,
        embeddedArbTimestamp: newerEmbeddedTimestamp,
      );

      await service.initialize(fetchUpdatesOnStart: false);

      // ASSERT 1: The cache is cleared (this part is the same)
      expect(service.getCacheStatus(), isEmpty);
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newerEmbeddedTimestamp,
      );

      // ARRANGE 2: Mock the API response for the upcoming refresh call.
      const String newestApiTimestamp = '2025-02-03T00:00:00Z';
      when(mockRepository.fetchUpdates(newerEmbeddedTimestamp)).thenAnswer(
        (final _) async => <String, dynamic>{
          'has_updates': true,
          'last_modified': newestApiTimestamp,
          'translations': <String, Map<String, String>>{
            'en': <String, String>{'key': 'newest value'},
          },
        },
      );

      // ACT 2: Trigger a refresh. This will now be the ONLY call to fetchUpdates.
      await service.refresh();

      // ASSERT 2: The assertions will now pass.
      verify(mockRepository.fetchUpdates(newerEmbeddedTimestamp))
          .called(1); // This will be 1 now
      expect(service.getOverride('en', 'key'), 'newest value');
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newestApiTimestamp,
      );
    });
  });

  group('Complex Lifecycle Simulation Tests', () {
    late SharedPreferences prefs;
    late MockApiRepository mockRepository;
    late TranslationService service;

    // This runs before each test in the group
    setUp(() async {
      // Start with a clean slate for SharedPreferences and create a new mock repository
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      mockRepository = MockApiRepository();
    });

    tearDown(() {
      // Dispose the service after each test
      service.dispose();
    });

    testWidgets(
        'simulates a full lifecycle of initial fetch, app update, and subsequent fetch',
        (final WidgetTester tester) async {
      // --- PHASE 1: First-time app run and initial API fetch ---

      // ARRANGE 1
      const String initialEmbeddedTimestamp = '2025-03-01T10:00:00Z';
      const String firstApiTimestamp = '2025-03-02T12:00:00Z';

      when(mockRepository.fetchUpdates(any)).thenAnswer(
        (final _) async => <String, dynamic>{
          'has_updates': true,
          'last_modified': firstApiTimestamp,
          'translations': <String, Map<String, String>>{
            'en': <String, String>{'greeting': 'Hello from API v1'},
          },
        },
      );

      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en'],
          projectId: 999, // Assuming you added this from the last fix
          secretKey: 'test-key', // Assuming you added this from the last fix
        ),
        repository: mockRepository,
        embeddedArbTimestamp: initialEmbeddedTimestamp,
      );

      // ACT 1: Initialize the service.
      await service.initialize();

      // --- THIS IS THE FIX ---
      // Wait for all pending timers and async operations (like the initial fetch) to complete.
      await tester.pumpAndSettle();

      // ASSERT 1: The cache will now be populated.
      expect(service.getOverride('en', 'greeting'), 'Hello from API v1');
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        firstApiTimestamp,
      );
      verify(mockRepository.fetchUpdates(any)).called(1);

      // --- PHASE 2: App Update (The rest of the test is likely correct) ---

      // ARRANGE 2
      const String newEmbeddedTimestamp = '2025-03-03T09:00:00Z';
      when(mockRepository.fetchUpdates(newEmbeddedTimestamp)).thenAnswer(
        (final _) async => <String, dynamic>{'has_updates': false},
      );

      service = TranslationService(
        config: const TranslationConfig(
          supportedLocales: <String>['en'],
          projectId: 999,
          secretKey: 'test-key',
        ),
        repository: mockRepository,
        embeddedArbTimestamp: newEmbeddedTimestamp,
      );

      // ACT 2
      // Using fetchUpdatesOnStart: false is good practice here to isolate the test phases
      await service.initialize(fetchUpdatesOnStart: false);
      await tester.pumpAndSettle();

      // ASSERT 2
      expect(service.getCacheStatus(), isEmpty);
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        newEmbeddedTimestamp,
      );

      // --- PHASE 3: A new API fetch after the app update ---

      // ARRANGE 3
      const String finalApiTimestamp = '2025-03-04T18:00:00Z';
      when(mockRepository.fetchUpdates(newEmbeddedTimestamp)).thenAnswer(
        (final _) async => <String, dynamic>{
          'has_updates': true,
          'last_modified': finalApiTimestamp,
          'translations': <String, Map<String, String>>{
            'en': <String, String>{
              'greeting': 'Hello from API v2 (the final version)',
            },
          },
        },
      );

      // ACT 3
      await service.refresh();
      await tester.pumpAndSettle();

      // ASSERT 3
      verify(mockRepository.fetchUpdates(newEmbeddedTimestamp)).called(1);
      expect(
        service.getOverride('en', 'greeting'),
        'Hello from API v2 (the final version)',
      );
      expect(
        prefs.getString('flutter_localisation_cache_timestamp'),
        finalApiTimestamp,
      );
    });
  });
}
