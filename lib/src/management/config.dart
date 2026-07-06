/// Local configuration + credential loading for the management CLI/MCP.
///
/// Two layers:
///  * **Project config** — `flutterlocalisation.json` in the project root (or a path passed
///    via `--config`). Holds `base_url`, `project_id`, `flavor`, and optional `arb_dir`.
///  * **Credentials** — the `flk_live_…` API token. Resolved from (in order):
///      1. `--token` flag / explicit argument,
///      2. `FL_API_TOKEN` environment variable,
///      3. `~/.config/flutterlocalisation/credentials.json` (written by `fl login`, chmod 600).
///
/// Pure Dart — safe under `dart run`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_localisation/src/management/exceptions.dart';

const String kDefaultBaseUrl = 'https://api.flutterlocalisation.com';
const String kProjectConfigName = 'flutterlocalisation.json';
const String kTokenEnvVar = 'FL_API_TOKEN';

class ProjectConfig {
  ProjectConfig({
    required this.baseUrl,
    required this.projectId,
    this.flavor,
    this.arbDir,
  });

  final String baseUrl;
  final int projectId;
  final String? flavor;
  final String? arbDir;

  /// Load from an explicit path, or search upward from [startDir] for
  /// `flutterlocalisation.json`.
  static ProjectConfig load({final String? path, final String? startDir}) {
    final File file = path != null
        ? File(path)
        : _findUpwards(startDir ?? Directory.current.path);
    if (!file.existsSync()) {
      throw ConfigException(
        'No project config found. Create `$kProjectConfigName` with '
        '{"base_url": "...", "project_id": <id>, "flavor": "..."} or pass --config.',
      );
    }
    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      throw ConfigException('Could not parse ${file.path}: $e');
    }
    final Object? pid = json['project_id'];
    if (pid is! int) {
      throw ConfigException('`project_id` (int) is required in ${file.path}.');
    }
    return ProjectConfig(
      baseUrl: (json['base_url'] as String?)?.trimRight() ?? kDefaultBaseUrl,
      projectId: pid,
      flavor: json['flavor'] as String?,
      arbDir: json['arb_dir'] as String?,
    );
  }

  static File _findUpwards(final String from) {
    Directory dir = Directory(from);
    while (true) {
      final File candidate = File('${dir.path}/$kProjectConfigName');
      if (candidate.existsSync()) return candidate;
      final Directory parent = dir.parent;
      if (parent.path == dir.path) {
        // Reached filesystem root — return the non-existent local path so the
        // caller emits a helpful "not found" message.
        return File('$from/$kProjectConfigName');
      }
      dir = parent;
    }
  }
}

/// Credential store for the `flk_live_…` token.
class Credentials {
  Credentials(this.token);

  final String token;

  /// Resolve a token from explicit arg → env var → credentials file.
  static Credentials resolve({final String? explicit, final String? baseUrl}) {
    if (explicit != null && explicit.isNotEmpty) return Credentials(explicit);

    final String? fromEnv = Platform.environment[kTokenEnvVar];
    if (fromEnv != null && fromEnv.isNotEmpty) return Credentials(fromEnv);

    final File file = _credentialsFile();
    if (file.existsSync()) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        // Prefer a base-url-specific token, else a default one.
        final Map<String, dynamic> byHost =
            (data['tokens'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        final String? scoped = baseUrl != null ? byHost[baseUrl] as String? : null;
        final String? token = scoped ?? data['token'] as String?;
        if (token != null && token.isNotEmpty) return Credentials(token);
      } catch (_) {
        // fall through to the error below
      }
    }

    throw AuthConfigException(
      'No API token found. Run `fl login --token flk_live_...`, set '
      '\$$kTokenEnvVar, or pass --token.',
    );
  }

  /// Persist a token to `~/.config/flutterlocalisation/credentials.json` (chmod 600).
  static void save(final String token, {final String? baseUrl}) {
    final File file = _credentialsFile();
    file.parent.createSync(recursive: true);

    Map<String, dynamic> data = <String, dynamic>{};
    if (file.existsSync()) {
      try {
        data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        data = <String, dynamic>{};
      }
    }
    if (baseUrl != null) {
      final Map<String, dynamic> byHost =
          (data['tokens'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      byHost[baseUrl] = token;
      data['tokens'] = byHost;
    } else {
      data['token'] = token;
    }
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    _chmod600(file);
  }

  static File _credentialsFile() {
    final String home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return File('$home/.config/flutterlocalisation/credentials.json');
  }

  static void _chmod600(final File file) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', <String>['600', file.path]);
    } catch (_) {
      // best effort
    }
  }
}
