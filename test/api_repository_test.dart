import 'dart:convert';
import 'dart:typed_data';

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
        supportedLocales: <String>['en'],
      );
    });

    test(
        'fetchUpdates returns null and does not make an API call if config is incomplete',
        () async {
      final TranslationConfig incompleteConfig = const TranslationConfig(
        projectId: 1,
        flavorName: 'production',
        supportedLocales: <String>['en'],
      );
      final MockClient mockClient =
          MockClient((final http.Request request) async {
        fail('HTTP client should not be called when config is incomplete.');
      });
      final ApiRepository repository =
          ApiRepository(incompleteConfig, mockClient);

      final Map<String, dynamic>? result = await repository.fetchUpdates('');

      expect(result, isNull);
    });

    test(
        'fetchUpdates sends no current_timestamp key for a new client and returns a decoded map',
        () async {
      // Arrange
      final Map<String, Object> expectedResponse = <String, Object>{
        'has_updates': true,
        'current_timestamp': '2025-06-18T15:10:00Z',
        'translations': <String, Map<String, String>>{
          'en': <String, String>{'appTitle': 'Live Title'},
        },
      };

      final MockClient mockClient =
          MockClient((final http.Request request) async {
        final Map<String, dynamic> body = jsonDecode(request.body);
        expect(body.containsKey('current_timestamp'), isFalse);
        expect(body['project_id'], 1);
        expect(body['flavor'], 'production');

        return http.Response(jsonEncode(expectedResponse), 200);
      });

      final ApiRepository repository =
          ApiRepository(configuredConfig, mockClient);

      final Map<String, dynamic>? result = await repository.fetchUpdates('');

      expect(result, equals(expectedResponse));
    });

    test(
        'fetchUpdates sends the correct current_timestamp string for an existing client',
        () async {
      // Arrange
      const String clientVersion = '2025-06-18T14:00:00Z';
      final MockClient mockClient =
          MockClient((final http.Request request) async {
        final body = jsonDecode(request.body);
        expect(body['current_timestamp'], clientVersion);

        return http.Response(
          jsonEncode(<String, bool>{'has_updates': false}),
          200,
        );
      });

      final ApiRepository repository =
          ApiRepository(configuredConfig, mockClient);

      await repository.fetchUpdates(clientVersion);
    });

    test('fetchUpdates correctly decodes UTF-8 characters in the response',
        () async {
      // Include the required has_updates field along with UTF-8 content
      final Map<String, Object> expectedResponse = <String, Object>{
        'has_updates': true,
        'last_modified': '2025-06-22T10:04:05.496424',
        'greeting': 'Héllö Wörld 🌍',
        'translations': <String, Map<String, String>>{
          'en': <String, String>{'welcome': 'Héllö Wörld 🌍'},
          'fr': <String, String>{'welcome': 'Bonjöur Möndé 🌍'},
        },
      };

      final MockClient mockClient =
          MockClient((final http.Request request) async {
        final Uint8List bodyBytes = utf8.encode(jsonEncode(expectedResponse));
        return http.Response.bytes(bodyBytes, 200);
      });
      final ApiRepository repository =
          ApiRepository(configuredConfig, mockClient);

      final Map<String, dynamic>? result = await repository.fetchUpdates('');

      expect(result, equals(expectedResponse));
    });

    test('fetchUpdates returns null on an API error (e.g., 401 Unauthorized)',
        () async {
      final MockClient mockClient =
          MockClient((final http.Request request) async {
        return http.Response('{"error": "Invalid API key"}', 401);
      });
      final ApiRepository repository =
          ApiRepository(configuredConfig, mockClient);

      final Map<String, dynamic>? result = await repository.fetchUpdates('');

      expect(result, isNull);
    });

    test('fetchUpdates returns null when a network error occurs', () async {
      final MockClient mockClient =
          MockClient((final http.Request request) async {
        throw http.ClientException('Failed to connect to host');
      });
      final ApiRepository repository =
          ApiRepository(configuredConfig, mockClient);

      final Map<String, dynamic>? result = await repository.fetchUpdates('');

      expect(result, isNull);
    });
  });
}
