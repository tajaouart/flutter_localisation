#!/usr/bin/env dart
/// `fl_mcp` — Model Context Protocol server for FlutterLocalisation.
///
/// Exposes translation-key management to Claude (or any MCP client) over stdio, reusing the
/// exact same `Operations` core as the `fl` CLI. Mutating tools follow a **preview → apply**
/// split: they run as a dry-run unless called with `"apply": true`, so the human confirms
/// the diff before anything is written.
///
/// Configuration via environment (set in the MCP client config):
///   FL_API_TOKEN   (required)  scoped flk_live_ token
///   FL_PROJECT_ID  (required)  numeric project id
///   FL_BASE_URL    (optional)  defaults to https://api.flutterlocalisation.com
///   FL_FLAVOR      (optional)  flavor name if the project has several
///
/// Run: `dart run flutter_localisation:fl_mcp`
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_localisation/src/management/config.dart';
import 'package:flutter_localisation/src/management/exceptions.dart';
import 'package:flutter_localisation/src/management/management_client.dart';
import 'package:flutter_localisation/src/management/operations.dart';

const String _protocolVersion = '2024-11-05';
const String _serverName = 'flutter-localisation';
const String _serverVersion = '2.1.5';

late final Operations _ops;
late final ManagementClient _client;

Future<void> main(final List<String> args) async {
  _bootstrap();

  // MCP stdio transport: newline-delimited JSON-RPC 2.0 messages.
  final Stream<String> lines =
      stdin.transform(utf8.decoder).transform(const LineSplitter());

  await for (final String line in lines) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      continue; // ignore unparseable lines
    }
    await _handle(msg);
  }
}

void _bootstrap() {
  final Map<String, String> env = Platform.environment;
  final String? token = env['FL_API_TOKEN'];
  final String? projectRaw = env['FL_PROJECT_ID'];
  if (token == null || token.isEmpty || projectRaw == null) {
    stderr.writeln('fl_mcp: FL_API_TOKEN and FL_PROJECT_ID are required.');
    exit(64);
  }
  final int? projectId = int.tryParse(projectRaw);
  if (projectId == null) {
    stderr.writeln('fl_mcp: FL_PROJECT_ID must be an integer.');
    exit(64);
  }
  final String baseUrl = env['FL_BASE_URL'] ?? kDefaultBaseUrl;
  _client = ManagementClient(baseUrl: baseUrl, token: token);
  _ops = Operations(_client, projectId, flavor: env['FL_FLAVOR']);
  stderr.writeln('fl_mcp: ready (project $projectId @ $baseUrl).');
}

Future<void> _handle(final Map<String, dynamic> msg) async {
  final Object? id = msg['id'];
  final String method = (msg['method'] ?? '') as String;

  // Notifications (no id) get no response.
  switch (method) {
    case 'initialize':
      _reply(id, <String, dynamic>{
        'protocolVersion': _protocolVersion,
        'capabilities': <String, dynamic>{'tools': <String, dynamic>{}},
        'serverInfo': <String, dynamic>{
          'name': _serverName,
          'version': _serverVersion,
        },
      });
      return;
    case 'ping':
      _reply(id, <String, dynamic>{});
      return;
    case 'tools/list':
      _reply(id, <String, dynamic>{'tools': _toolDefinitions()});
      return;
    case 'tools/call':
      await _callTool(id, (msg['params'] ?? const <String, dynamic>{}) as Map<String, dynamic>);
      return;
    case 'notifications/initialized':
    case 'notifications/cancelled':
      return; // no-op notifications
    default:
      if (id != null) {
        _error(id, -32601, 'Method not found: $method');
      }
  }
}

// --------------------------------------------------------------------------- //
// Tools
// --------------------------------------------------------------------------- //

List<Map<String, dynamic>> _toolDefinitions() => <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'list_status',
        'description':
            'List every locale for the project with translation completion counts. '
                'Read-only; call this first to understand the current state.',
        'inputSchema': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
      <String, dynamic>{
        'name': 'add_string',
        'description':
            'Add a new translation key with its base-language value. Set translate=true to '
                'AI-fill all other locales. Preview by default; pass apply=true to write.',
        'inputSchema': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'key': <String, dynamic>{'type': 'string', 'description': 'The translation key.'},
            'value': <String, dynamic>{'type': 'string', 'description': 'Base-language value.'},
            'translate': <String, dynamic>{
              'type': 'boolean',
              'description': 'AI-translate all other locales after adding.',
              'default': false,
            },
            'apply': <String, dynamic>{
              'type': 'boolean',
              'description': 'false = preview only (default); true = actually write.',
              'default': false,
            },
          },
          'required': <String>['key', 'value'],
        },
      },
      <String, dynamic>{
        'name': 'edit_string',
        'description':
            "Edit one locale's value of an existing key. Preview by default; apply=true writes.",
        'inputSchema': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'key': <String, dynamic>{'type': 'string'},
            'locale': <String, dynamic>{'type': 'string', 'description': 'e.g. fr'},
            'value': <String, dynamic>{'type': 'string'},
            'apply': <String, dynamic>{'type': 'boolean', 'default': false},
          },
          'required': <String>['key', 'locale', 'value'],
        },
      },
      <String, dynamic>{
        'name': 'delete_string',
        'description':
            'Delete a key entirely (all locales) or, with locale, just one locale. '
                'Preview by default; apply=true writes.',
        'inputSchema': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'key': <String, dynamic>{'type': 'string'},
            'locale': <String, dynamic>{
              'type': 'string',
              'description': 'Optional; omit to delete all locales of the key.',
            },
            'apply': <String, dynamic>{'type': 'boolean', 'default': false},
          },
          'required': <String>['key'],
        },
      },
      <String, dynamic>{
        'name': 'translate_key',
        'description':
            "AI-translate a key's locales. Default: only missing locales. all=true does every "
                'non-base locale; or pass a specific locales list. Preview by default; apply=true writes.',
        'inputSchema': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'key': <String, dynamic>{'type': 'string'},
            'all': <String, dynamic>{'type': 'boolean', 'default': false},
            'locales': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
            },
            'apply': <String, dynamic>{'type': 'boolean', 'default': false},
          },
          'required': <String>['key'],
        },
      },
    ];

Future<void> _callTool(final Object? id, final Map<String, dynamic> params) async {
  final String name = (params['name'] ?? '') as String;
  final Map<String, dynamic> a =
      (params['arguments'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
  final bool apply = (a['apply'] ?? false) as bool;

  try {
    final OpResult r;
    switch (name) {
      case 'list_status':
        r = await _ops.status();
      case 'add_string':
        r = await _ops.add(
          a['key'] as String,
          a['value'] as String,
          translate: (a['translate'] ?? false) as bool,
          dryRun: !apply,
        );
      case 'edit_string':
        r = await _ops.edit(
          a['key'] as String,
          a['locale'] as String,
          value: a['value'] as String?,
          dryRun: !apply,
        );
      case 'delete_string':
        r = await _ops.delete(
          a['key'] as String,
          locale: a['locale'] as String?,
          dryRun: !apply,
        );
      case 'translate_key':
        r = await _ops.translate(
          a['key'] as String,
          all: (a['all'] ?? false) as bool,
          locales: (a['locales'] as List<dynamic>?)?.cast<String>(),
          dryRun: !apply,
        );
      default:
        _error(id, -32602, 'Unknown tool: $name');
        return;
    }
    _toolResult(id, r.toJson(), isError: !r.ok);
  } on ManagementException catch (e) {
    _toolResult(id, <String, dynamic>{'ok': false, 'error': e.message}, isError: true);
  }
}

// --------------------------------------------------------------------------- //
// JSON-RPC framing
// --------------------------------------------------------------------------- //

void _toolResult(final Object? id, final Map<String, dynamic> data,
    {final bool isError = false}) {
  _reply(id, <String, dynamic>{
    'content': <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'text',
        'text': const JsonEncoder.withIndent('  ').convert(data),
      },
    ],
    'isError': isError,
  });
}

void _reply(final Object? id, final Map<String, dynamic> result) {
  _write(<String, dynamic>{'jsonrpc': '2.0', 'id': id, 'result': result});
}

void _error(final Object? id, final int code, final String message) {
  _write(<String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'error': <String, dynamic>{'code': code, 'message': message},
  });
}

void _write(final Map<String, dynamic> msg) {
  stdout.writeln(jsonEncode(msg));
}
