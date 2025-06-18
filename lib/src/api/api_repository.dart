import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../flutter_localisation.dart';

class ApiRepository {
  final TranslationConfig _config;
  final http.Client _httpClient;

  ApiRepository(this._config, this._httpClient);

  Future<Map<String, dynamic>?> fetchUpdates(String currentVersion) async {
    // API is only called for configured (paid) users.
    if (_config.secretKey == null ||
        _config.projectId == null ||
        _config.flavorName == null) {
      return null;
    }

    final uri = Uri.parse(
      'https://api.flutterlocalisation.com/api/v1/translations/live-update/',
    );

    final Map<String, dynamic> payload = {
      'project_id': _config.projectId,
      'flavor': _config.flavorName,
    };

    if (currentVersion.isNotEmpty) {
      payload['current_version'] = currentVersion;
    }

    try {
      final response = await _httpClient.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_config.secretKey}',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Use utf8.decode to ensure proper handling of all characters.
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        _logError('API Error ${response.statusCode}: Failed to fetch updates.');
        return null;
      }
    } catch (e) {
      _logError('Network Error: Failed to fetch updates. $e');
      return null;
    }
  }

  void _logError(String message) {
    if (_config.enableLogging) {
      debugPrint('[FlutterLocalisation] ERROR: $message');
    }
  }
}
