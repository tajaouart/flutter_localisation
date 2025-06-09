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
      // A standard, valid configuration for most tests
      configuredConfig = const TranslationConfig(
        secretKey: 'sk_test_123',
        projectId: 1,
        flavorName: 'production',
        enableLogging: false,
        // Disable logging during tests for cleaner output
        supportedLocales: ['en'],
      );
    });

    test(
        'fetchUpdates returns null and does not make an API call if config is incomplete',
        () async {
      // Arrange
      // Create a config without the required secretKey
      final incompleteConfig = TranslationConfig(
        projectId: 1,
        flavorName: 'production',
        supportedLocales: ['en'],
      );

      // The MockClient will throw an error if it's called, proving it was not.
      final mockClient = MockClient((request) async {
        fail('HTTP client should not be called when config is incomplete.');
      });

      final repository = ApiRepository(incompleteConfig, mockClient);

      // Act
      final result = await repository.fetchUpdates(0);

      // Assert
      expect(result, isNull);
    });

    test('fetchUpdates returns a decoded map on a successful 200 OK response',
        () async {
      // Arrange
      final expectedResponse = {
        'has_updates': true,
        'version': 2,
        'translations': {
          'en': {'appTitle': 'Live Title'}
        }
      };

      final mockClient = MockClient((request) async {
        // Assert that the request has the correct properties
        expect(request.method, 'POST');
        expect(
          request.url.toString().endsWith('/api/v1/translations/live-update/'),
          true,
        );
        expect(request.headers['Authorization'], 'Bearer sk_test_123');
        expect(
            request.headers['Content-Type'], 'application/json; charset=UTF-8');

        final body = jsonDecode(request.body);
        expect(body['project_id'], 1);
        expect(body['flavor'], 'production');
        expect(body['current_version'], 0);

        // Return a successful response
        return http.Response(jsonEncode(expectedResponse), 200, headers: {
          'Content-Type': 'application/json; charset=utf-8',
        });
      });

      final repository = ApiRepository(configuredConfig, mockClient);

      // Act
      final result = await repository.fetchUpdates(0);

      // Assert
      expect(result, equals(expectedResponse));
    });

    test('fetchUpdates correctly decodes UTF-8 characters in the response',
        () async {
      // Arrange
      final expectedResponse = {
        'greeting': 'Héllö Wörld 🌍',
      };

      final mockClient = MockClient((request) async {
        // Manually encode the body to bytes to ensure we test the decoding part
        final bodyBytes = utf8.encode(jsonEncode(expectedResponse));
        return http.Response.bytes(bodyBytes, 200);
      });

      final repository = ApiRepository(configuredConfig, mockClient);

      // Act
      final result = await repository.fetchUpdates(0);

      // Assert
      expect(result, equals(expectedResponse));
    });

    test('fetchUpdates returns null on an API error (e.g., 401 Unauthorized)',
        () async {
      // Arrange
      final mockClient = MockClient((request) async {
        // Simulate a server error
        return http.Response('{"error": "Invalid API key"}', 401);
      });

      final repository = ApiRepository(configuredConfig, mockClient);

      // Act
      final result = await repository.fetchUpdates(0);

      // Assert
      expect(result, isNull);
    });

    test('fetchUpdates returns null when a network error occurs', () async {
      // Arrange
      final mockClient = MockClient((request) async {
        // Simulate a network failure
        throw http.ClientException('Failed to connect to host');
      });

      final repository = ApiRepository(configuredConfig, mockClient);

      // Act
      final result = await repository.fetchUpdates(0);

      // Assert
      expect(result, isNull);
    });
  });
}
