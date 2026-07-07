/// Management API client — the shared core for the CLI and the MCP server.
///
/// Mirrors exactly what the dashboard does: add key, edit translation (value / plural /
/// placeholders), delete translation, AI-translate (persisted via batch), and read the
/// project to resolve `(key, locale) → translation_id`.
///
/// Pure Dart (`dart:io` + `http`), no Flutter imports — runs under `dart run`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter_localisation/src/management/exceptions.dart';

// --------------------------------------------------------------------------- //
// Data models
// --------------------------------------------------------------------------- //

class TranslationEntry {
  TranslationEntry({
    required this.id,
    required this.key,
    required this.value,
    required this.isChecked,
    required this.isPluralEnabled,
    required this.isAiTranslated,
  });

  final int id;
  final String key;
  final String value;
  final bool isChecked;
  final bool isPluralEnabled;
  final bool isAiTranslated;

  bool get isEmpty => value.trim().isEmpty && !isPluralEnabled;

  factory TranslationEntry.fromJson(final Map<String, dynamic> j) => TranslationEntry(
        id: j['id'] as int,
        key: (j['key'] ?? '') as String,
        value: (j['value'] ?? '') as String,
        isChecked: (j['is_checked'] ?? false) as bool,
        isPluralEnabled: (j['is_plural_enabled'] ?? false) as bool,
        isAiTranslated: (j['is_ai_translated'] ?? false) as bool,
      );
}

class LanguageData {
  LanguageData({
    required this.code,
    required this.isBase,
    required this.translations,
  });

  final String code;
  final bool isBase;
  final List<TranslationEntry> translations;

  factory LanguageData.fromJson(final Map<String, dynamic> j) => LanguageData(
        code: (j['code'] ?? '') as String,
        isBase: (j['is_base_language'] ?? false) as bool,
        translations: ((j['translations'] ?? const <dynamic>[]) as List)
            .map((final e) => TranslationEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FlavorData {
  FlavorData({required this.name, required this.languages});

  final String name;
  final List<LanguageData> languages;

  factory FlavorData.fromJson(final Map<String, dynamic> j) => FlavorData(
        name: (j['name'] ?? '') as String,
        languages: ((j['languages'] ?? const <dynamic>[]) as List)
            .map((final e) => LanguageData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProjectData {
  ProjectData({required this.id, required this.name, required this.flavors});

  final int id;
  final String name;
  final List<FlavorData> flavors;

  factory ProjectData.fromJson(final Map<String, dynamic> j) => ProjectData(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        flavors: ((j['flavors'] ?? const <dynamic>[]) as List)
            .map((final e) => FlavorData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Choose a flavor by [name]; if null and exactly one flavor exists, use it.
  FlavorData flavor(final String? name) {
    if (name != null) {
      return flavors.firstWhere(
        (final FlavorData f) => f.name == name,
        orElse: () => throw ResolveException(
          'Flavor "$name" not found. Available: ${flavors.map((final FlavorData f) => f.name).join(", ")}.',
        ),
      );
    }
    if (flavors.length == 1) return flavors.first;
    throw ResolveException(
      'Multiple flavors exist (${flavors.map((final FlavorData f) => f.name).join(", ")}); '
      'specify one with --flavor.',
    );
  }

  LanguageData? baseLanguage(final String? flavorName) {
    final FlavorData f = flavor(flavorName);
    for (final LanguageData l in f.languages) {
      if (l.isBase) return l;
    }
    return f.languages.isEmpty ? null : f.languages.first;
  }

  /// Resolve `(key, locale) → translation id` within a flavor.
  int resolveId(final String key, final String locale, {final String? flavorName}) {
    final FlavorData f = flavor(flavorName);
    final LanguageData lang = f.languages.firstWhere(
      (final LanguageData l) => l.code == locale,
      orElse: () => throw ResolveException(
        'Locale "$locale" not found in flavor "${f.name}".',
      ),
    );
    final TranslationEntry entry = lang.translations.firstWhere(
      (final TranslationEntry t) => t.key == key,
      orElse: () =>
          throw ResolveException('Key "$key" not found for locale "$locale".'),
    );
    return entry.id;
  }

  /// All `(locale, id)` pairs for [key] in a flavor (every locale).
  List<({String locale, int id, bool empty})> entriesForKey(
    final String key, {
    final String? flavorName,
  }) {
    final FlavorData f = flavor(flavorName);
    final List<({String locale, int id, bool empty})> out = <({bool empty, int id, String locale})>[];
    for (final LanguageData l in f.languages) {
      for (final TranslationEntry t in l.translations) {
        if (t.key == key) {
          out.add((locale: l.code, id: t.id, empty: t.isEmpty));
        }
      }
    }
    return out;
  }
}

class BatchTranslateResult {
  BatchTranslateResult({
    required this.status,
    required this.successCount,
    required this.failedCount,
    required this.failed,
  });

  final String status; // success | partial | error
  final int successCount;
  final int failedCount;
  final List<({int id, String error})> failed;

  factory BatchTranslateResult.fromJson(final Map<String, dynamic> j) {
    final Map<String, dynamic> r =
        (j['results'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    return BatchTranslateResult(
      status: (j['status'] ?? 'success') as String,
      successCount: (r['success_count'] ?? 0) as int,
      failedCount: (r['failed_count'] ?? 0) as int,
      failed: ((r['failed'] ?? const <dynamic>[]) as List)
          .map((final e) => (
                id: (e['translation_id'] ?? 0) as int,
                error: (e['error'] ?? '') as String,
              ),)
          .toList(),
    );
  }
}

/// A lightweight project entry from `GET /api/projects/` (no translations).
class ProjectSummary {
  ProjectSummary({
    required this.id,
    required this.name,
    required this.workspace,
    required this.flavors,
    this.gitNeedsReauth = false,
  });

  final int id;
  final String name;
  final String workspace;
  final List<FlavorSummary> flavors;

  /// True when the backend's git provider token is dead and needs reconnecting in the
  /// dashboard — ARB pushes are failing, so `pull` won't see new strings.
  final bool gitNeedsReauth;

  factory ProjectSummary.fromJson(final Map<String, dynamic> j) =>
      ProjectSummary(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        workspace: (j['workspace'] ?? '') as String,
        gitNeedsReauth: (j['git_needs_reauth'] ?? false) as bool,
        flavors: ((j['flavors'] ?? const <dynamic>[]) as List)
            .map((final e) =>
                FlavorSummary.fromJson(e as Map<String, dynamic>),)
            .toList(),
      );
}

class FlavorSummary {
  FlavorSummary({
    required this.name,
    required this.baseLanguage,
    required this.languages,
  });

  final String name;
  final String? baseLanguage;
  final List<String> languages;

  factory FlavorSummary.fromJson(final Map<String, dynamic> j) => FlavorSummary(
        name: (j['name'] ?? '') as String,
        baseLanguage: j['base_language'] as String?,
        languages: ((j['languages'] ?? const <dynamic>[]) as List)
            .map((final e) => e as String)
            .toList(),
      );
}

// --------------------------------------------------------------------------- //
// Client
// --------------------------------------------------------------------------- //

class ManagementClient {
  ManagementClient({
    required this.baseUrl,
    required this.token,
    final http.Client? httpClient,
    this.maxRetries = 3,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String token;
  final int maxRetries;
  final http.Client _http;

  void close() => _http.close();

  Map<String, String> get _headers => <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(final String path) => Uri.parse('$baseUrl$path');

  /// List the projects (with flavors + locales) this token/user can access.
  Future<List<ProjectSummary>> listProjects() async {
    final http.Response res = await _send('GET', '/api/projects/');
    final List<dynamic> raw =
        (_json(res)['projects'] ?? const <dynamic>[]) as List<dynamic>;
    return raw
        .map((final dynamic e) =>
            ProjectSummary.fromJson(e as Map<String, dynamic>),)
        .toList();
  }

  /// GET the full project (structure + translation ids).
  Future<ProjectData> getProject(final int projectId) async {
    final http.Response res =
        await _send('GET', '/api/projects/$projectId/');
    return ProjectData.fromJson(_json(res));
  }

  /// Add a translation key with its base value. Idempotent server-side.
  Future<void> addKey(final int projectId, final String key, final String baseValue) async {
    await _send(
      'POST',
      '/api/projects/$projectId/translation_keys/',
      body: <String, String>{'key': key, 'base_value': baseValue},
    );
  }

  /// Update a single translation. Only non-null fields are sent (partial update).
  Future<Map<String, dynamic>> updateTranslation(
    final int translationId, {
    final String? value,
    final bool? isPluralEnabled,
    final String? zeroCase,
    final String? singularCase,
    final String? pluralCase,
    final String? pluralParam,
    final bool? isPlaceholdersEnabled,
    final Map<String, dynamic>? placeholders,
    final bool? isChecked,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      if (value != null) 'value': value,
      if (isPluralEnabled != null) 'is_plural_enabled': isPluralEnabled,
      if (zeroCase != null) 'zero_case': zeroCase,
      if (singularCase != null) 'singular_case': singularCase,
      if (pluralCase != null) 'plural_case': pluralCase,
      if (pluralParam != null) 'plural_param': pluralParam,
      if (isPlaceholdersEnabled != null)
        'is_placeholders_enabled': isPlaceholdersEnabled,
      if (placeholders != null) 'placeholders': placeholders,
      if (isChecked != null) 'is_checked': isChecked,
    };
    final http.Response res =
        await _send('POST', '/api/update_translation/$translationId/', body: body);
    return _json(res);
  }

  /// Delete a single translation (one locale of a key).
  Future<void> deleteTranslation(final int translationId) async {
    await _send('DELETE', '/api/translations/$translationId/delete/');
  }

  /// Delete an entire key (all locales) by name — removes the TranslationKey itself,
  /// not just its translations.
  Future<void> deleteKey(final int projectId, final String key) async {
    await _send(
      'POST',
      '/api/projects/$projectId/translation_keys/delete/',
      body: <String, dynamic>{'key': key},
    );
  }

  /// AI-translate and persist a set of translations (uses the batch endpoint,
  /// which — unlike the single endpoint — saves).
  Future<BatchTranslateResult> aiBatchTranslate(final List<int> ids) async {
    final http.Response res = await _send(
      'POST',
      '/api/ai_batch_translate/',
      body: <String, List<int>>{'translation_ids': ids},
      // 207 (partial) is an expected, non-fatal outcome.
      acceptStatuses: const <int>{200, 207},
    );
    return BatchTranslateResult.fromJson(_json(res));
  }

  // ------------------------------------------------------------------------- //
  // HTTP plumbing: retries + error mapping
  // ------------------------------------------------------------------------- //

  Future<http.Response> _send(
    final String method,
    final String path, {
    final Object? body,
    final Set<int> acceptStatuses = const <int>{200, 201, 204},
  }) async {
    final Uri uri = _uri(path);
    final String? encoded = body == null ? null : jsonEncode(body);

    int attempt = 0;
    while (true) {
      attempt++;
      http.Response res;
      try {
        final http.Request req = http.Request(method, uri)
          ..headers.addAll(_headers);
        if (encoded != null) req.body = encoded;
        final http.StreamedResponse streamed = await _http.send(req);
        res = await http.Response.fromStream(streamed);
      } catch (e) {
        if (attempt <= maxRetries) {
          await _backoff(attempt);
          continue;
        }
        throw ManagementException('Network error calling $method $path: $e');
      }

      if (acceptStatuses.contains(res.statusCode)) return res;

      // Retry transient failures.
      if ((res.statusCode == 429 || res.statusCode >= 500) &&
          attempt <= maxRetries) {
        await _backoff(attempt, retryAfter: res.headers['retry-after']);
        continue;
      }

      throw _errorFor(method, path, res);
    }
  }

  ApiException _errorFor(final String method, final String path, final http.Response res) {
    Map<String, dynamic>? parsed;
    String message;
    try {
      parsed = jsonDecode(res.body) as Map<String, dynamic>;
      message = (parsed['message'] ?? parsed['detail'] ?? res.reasonPhrase ?? '')
          .toString();
    } catch (_) {
      message = res.reasonPhrase ?? 'Request failed';
    }
    if (message.isEmpty) message = '$method $path failed';
    return ApiException(res.statusCode, message, body: parsed);
  }

  Map<String, dynamic> _json(final http.Response res) {
    if (res.body.isEmpty) return const <String, dynamic>{};
    final Object? decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  Future<void> _backoff(final int attempt, {final String? retryAfter}) async {
    if (retryAfter != null) {
      final int? secs = int.tryParse(retryAfter);
      if (secs != null) {
        await Future<void>.delayed(Duration(seconds: secs));
        return;
      }
    }
    // Exponential backoff: 0.4s, 0.8s, 1.6s ...
    await Future<void>.delayed(Duration(milliseconds: 200 * (1 << attempt)));
  }
}
