import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:http/http.dart' as http;

class ApiRepository {
  final TranslationConfig _config;
  final http.Client _httpClient;

  ApiRepository(this._config, this._httpClient);

  /// Fetch updates since the given timestamp
  /// [currentTimestamp] should be in ARB @@last_modified format: "2025-06-22T10:04:05.496424"
  Future<Map<String, dynamic>?> fetchUpdates(
    final String currentTimestamp,
  ) async {
    // API is only called for configured (paid) users.
    if (_config.secretKey == null ||
        _config.projectId == null ||
        _config.flavorName == null) {
      return null;
    }

    final Uri uri = Uri.parse(
      'https://api.flutterlocalisation.com/api/v1/translations/live-update/',
    );

    final Map<String, dynamic> payload = <String, dynamic>{
      'project_id': _config.projectId,
      'flavor': _config.flavorName,
    };

    // Send timestamp instead of version
    if (currentTimestamp.isNotEmpty) {
      payload['current_timestamp'] = currentTimestamp;
    }

    try {
      final http.Response response = await _httpClient.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer ${_config.secretKey}',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Use utf8.decode to ensure proper handling of all characters.
        final Map<String, dynamic> responseData =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // Validate that the response contains the expected fields
        if (responseData.containsKey('has_updates')) {
          return responseData;
        } else {
          _logError('Invalid API response: missing has_updates field');
          return null;
        }
      } else {
        _logError('API Error ${response.statusCode}: Failed to fetch updates.');
        return null;
      }
    } on Exception catch (e) {
      _logError('Network Error: Failed to fetch updates. $e');
      return null;
    }
  }

  void _logError(final String message) {
    if (_config.enableLogging) {
      debugPrint('[FlutterLocalisation] ERROR: $message');
    }
  }
}
