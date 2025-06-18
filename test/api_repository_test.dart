import 'dart:convert';

import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_localisation/src/api/api_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiRepository', () {
    late TranslationConfig configuredConfig;

    setUp(() {
      configuredConfig = const TranslationConfig(
        secretKey: 'sk_test_123',
        projectId: 1,
        flavorName: 'production',
        enableLogging: false,
        supportedLocales: ['en'],
      );
    });

    test(
        'fetchUpdates returns null and does not make an API call if config is incomplete',
        () async {
      final incompleteConfig = TranslationConfig(
        projectId: 1,
        flavorName: 'production',
        supportedLocales: ['en'],
      );
      final mockClient = MockClient((request) async {
        fail('HTTP client should not be called when config is incomplete.');
      });
      final repository = ApiRepository(incompleteConfig, mockClient);

      final result = await repository.fetchUpdates('');

      expect(result, isNull);
    });

    test(
        'fetchUpdates sends no version key for a new client and returns a decoded map',
        () async {
      // Arrange
      final expectedResponse = {
        'has_updates': true,
        'version': '2025-06-18T15:10:00Z',
        'translations': {
          'en': {'appTitle': 'Live Title'}
        }
      };

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body.containsKey('current_version'), isFalse);
        expect(body['project_id'], 1);
        expect(body['flavor'], 'production');

        return http.Response(jsonEncode(expectedResponse), 200);
      });

      final repository = ApiRepository(configuredConfig, mockClient);

      final result = await repository.fetchUpdates('');

      expect(result, equals(expectedResponse));
    });

    test('fetchUpdates sends the correct version string for an existing client',
        () async {
      // Arrange
      const clientVersion = '2025-06-18T14:00:00Z';
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['current_version'], clientVersion);

        return http.Response(jsonEncode({'has_updates': false}), 200);
      });

      final repository = ApiRepository(configuredConfig, mockClient);

      await repository.fetchUpdates(clientVersion);
    });

    test('fetchUpdates correctly decodes UTF-8 characters in the response',
        () async {
      final expectedResponse = {'greeting': 'Héllö Wörld 🌍'};
      final mockClient = MockClient((request) async {
        final bodyBytes = utf8.encode(jsonEncode(expectedResponse));
        return http.Response.bytes(bodyBytes, 200);
      });
      final repository = ApiRepository(configuredConfig, mockClient);

      final result = await repository.fetchUpdates('');

      expect(result, equals(expectedResponse));
    });

    test('fetchUpdates returns null on an API error (e.g., 401 Unauthorized)',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Invalid API key"}', 401);
      });
      final repository = ApiRepository(configuredConfig, mockClient);

      final result = await repository.fetchUpdates('');

      expect(result, isNull);
    });

    test('fetchUpdates returns null when a network error occurs', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Failed to connect to host');
      });
      final repository = ApiRepository(configuredConfig, mockClient);

      final result = await repository.fetchUpdates('');

      expect(result, isNull);
    });
  });
}
