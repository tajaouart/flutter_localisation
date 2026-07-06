#!/usr/bin/env dart
/// `fl` — FlutterLocalisation management CLI.
///
/// Add / edit / delete translation keys and strings — full parity with the dashboard —
/// straight from the terminal, then `git pull` the regenerated ARBs. Auth uses a scoped
/// `flk_live_…` API token (create one in the dashboard, or `fl login --token ...`).
///
///   dart run flutter_localisation:fl add greeting --value "Hello" --translate
///   dart run flutter_localisation:fl edit greeting --locale fr --value "Bonjour"
///   dart run flutter_localisation:fl delete greeting
///   dart run flutter_localisation:fl translate greeting --missing
///   dart run flutter_localisation:fl status
///   dart run flutter_localisation:fl pull
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:flutter_localisation/src/management/config.dart';
import 'package:flutter_localisation/src/management/exceptions.dart';
import 'package:flutter_localisation/src/management/management_client.dart';
import 'package:flutter_localisation/src/management/operations.dart';
import 'package:flutter_localisation/src/management/project_resolver.dart';

Future<void> main(final List<String> args) async {
  final CommandRunner<int> runner = CommandRunner<int>(
    'fl',
    'FlutterLocalisation management CLI — manage translation keys from the terminal.',
  )
    ..argParser.addOption('config', help: 'Path to flutterlocalisation.json.')
    ..argParser.addOption('token', help: 'flk_live_ API token (overrides env/file).')
    ..argParser.addOption('project',
        help: 'Project name or id (overrides config; use `fl projects` to list).',)
    ..argParser.addOption('flavor', help: 'Flavor name (if the project has several).')
    ..argParser.addFlag('dry-run',
        negatable: false, help: 'Show what would happen without changing anything.',)
    ..argParser.addFlag('json',
        negatable: false, help: 'Emit machine-readable JSON.',);

  runner.addCommand(LoginCommand());
  runner.addCommand(ProjectsCommand());
  runner.addCommand(AddCommand());
  runner.addCommand(EditCommand());
  runner.addCommand(DeleteCommand());
  runner.addCommand(TranslateCommand());
  runner.addCommand(StatusCommand());
  runner.addCommand(PullCommand());

  try {
    final int? code = await runner.run(args);
    exit(code ?? 0);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } on ManagementException catch (e) {
    stderr.writeln('Error: ${e.message}');
    if (e is ApiException && e.isForbidden) {
      stderr.writeln('Hint: your token may lack the required scope, or the plan '
          'limit was reached.');
    }
    if (e is ApiException && e.isAuth) {
      stderr.writeln('Hint: run `fl login --token flk_live_...` or set \$FL_API_TOKEN.');
    }
    exit(1);
  }
}

/// Shared helpers for commands that talk to the API.
mixin _ApiCommand on Command<int> {
  bool get jsonOut => (globalResults?['json'] as bool?) ?? false;
  bool get dryRun => (globalResults?['dry-run'] as bool?) ?? false;

  ProjectConfig loadProject() =>
      ProjectConfig.load(path: globalResults?['config'] as String?);

  ManagementClient buildClient(final ProjectConfig cfg) {
    final Credentials creds = Credentials.resolve(
      explicit: globalResults?['token'] as String?,
      baseUrl: cfg.baseUrl,
    );
    return ManagementClient(baseUrl: cfg.baseUrl, token: creds.token);
  }

  /// Resolve the target project (by id/name, or the sole project) and build [Operations].
  Future<({ManagementClient client, Operations ops, String projectName})> build(
    final ProjectConfig cfg,
  ) async {
    final ManagementClient client = buildClient(cfg);
    final String? projectArg = globalResults?['project'] as String?;
    final String? flavor = (globalResults?['flavor'] as String?) ?? cfg.flavor;

    // Fast path: an explicit numeric id in config and no name override — no lookup needed.
    if (projectArg == null && cfg.projectId != null) {
      return (
        client: client,
        ops: Operations(client, cfg.projectId!, flavor: flavor),
        projectName: cfg.project ?? 'project ${cfg.projectId}',
      );
    }

    final ProjectResolver resolver = ProjectResolver(
      client,
      defaultProject: cfg.projectSelector,
      defaultFlavor: flavor,
    );
    final ResolvedTarget target =
        await resolver.resolve(project: projectArg, flavor: flavor);
    return (
      client: client,
      ops: Operations(client, target.projectId, flavor: target.flavor),
      projectName: target.projectName,
    );
  }

  int emit(final OpResult r) {
    if (jsonOut) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(r.toJson()));
    } else {
      stdout.writeln(r.ok ? '✓ ${r.message}' : '✗ ${r.message}');
    }
    return r.ok ? 0 : 1;
  }
}

class LoginCommand extends Command<int> {
  LoginCommand() {
    argParser.addOption('token', mandatory: true, help: 'flk_live_ API token.');
    argParser.addOption('base-url',
        defaultsTo: kDefaultBaseUrl, help: 'API base URL to associate the token with.',);
  }

  @override
  String get name => 'login';
  @override
  String get description => 'Store a scoped API token (~/.config, chmod 600).';

  @override
  Future<int> run() async {
    final String token = argResults!['token'] as String;
    final String baseUrl = argResults!['base-url'] as String;
    if (!token.startsWith('flk_')) {
      stderr.writeln('Warning: token does not look like a flk_ key.');
    }
    Credentials.save(token, baseUrl: baseUrl);
    stdout.writeln('✓ Token saved for $baseUrl.');
    return 0;
  }
}

class ProjectsCommand extends Command<int> with _ApiCommand {
  @override
  String get name => 'projects';
  @override
  String get description => 'List the projects (and flavors) you can access.';

  @override
  Future<int> run() async {
    final ManagementClient client = buildClient(loadProject());
    try {
      final List<ProjectSummary> projects = await client.listProjects();
      if (jsonOut) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(
          projects
              .map((final ProjectSummary p) => <String, dynamic>{
                    'id': p.id,
                    'name': p.name,
                    'workspace': p.workspace,
                    'flavors': p.flavors
                        .map((final FlavorSummary f) => <String, dynamic>{
                              'name': f.name,
                              'base': f.baseLanguage,
                              'locales': f.languages,
                            },)
                        .toList(),
                  },)
              .toList(),
        ),);
        return 0;
      }
      if (projects.isEmpty) {
        stdout.writeln('No projects accessible with this token.');
        return 0;
      }
      for (final ProjectSummary p in projects) {
        stdout.writeln('${p.name}  (id ${p.id})');
        for (final FlavorSummary f in p.flavors) {
          final String base =
              f.baseLanguage != null ? '  [base ${f.baseLanguage}]' : '';
          stdout.writeln('  · ${f.name}: ${f.languages.join(", ")}$base');
        }
      }
      return 0;
    } finally {
      client.close();
    }
  }
}

class AddCommand extends Command<int> with _ApiCommand {
  AddCommand() {
    argParser.addOption('value', mandatory: true, help: 'Base-language value.');
    argParser.addFlag('translate',
        abbr: 't', negatable: false, help: 'AI-translate all other locales.',);
  }

  @override
  String get name => 'add';
  @override
  String get description => 'Add a translation key with its base value.';
  @override
  String get invocation => 'fl add <key> --value "<text>" [--translate]';

  @override
  Future<int> run() async {
    final String key = _requireKey(this);
    final ({ManagementClient client, Operations ops, String projectName}) built = await build(loadProject());
    try {
      final OpResult r = await built.ops.add(
        key,
        argResults!['value'] as String,
        translate: argResults!['translate'] as bool,
        dryRun: dryRun,
      );
      return emit(r);
    } finally {
      built.client.close();
    }
  }
}

class EditCommand extends Command<int> with _ApiCommand {
  EditCommand() {
    argParser.addOption('locale', mandatory: true, help: 'Locale code, e.g. fr.');
    argParser.addOption('value', help: 'New value.');
    argParser.addFlag('checked', defaultsTo: null, help: 'Set is_checked true/false.',);
    argParser.addMultiOption('placeholder',
        help: 'Placeholder as name:type (repeatable), e.g. --placeholder count:num.',);
  }

  @override
  String get name => 'edit';
  @override
  String get description => 'Edit a locale\'s value / flags of an existing key.';
  @override
  String get invocation => 'fl edit <key> --locale <code> [--value "..."]';

  @override
  Future<int> run() async {
    final String key = _requireKey(this);
    final List<String> phs = argResults!['placeholder'] as List<String>;
    Map<String, dynamic>? placeholders;
    if (phs.isNotEmpty) {
      placeholders = <String, dynamic>{
        for (final String p in phs)
          p.split(':').first: <String, String>{'type': p.contains(':') ? p.split(':').last : 'String'},
      };
    }
    final ({ManagementClient client, Operations ops, String projectName}) built = await build(loadProject());
    try {
      final OpResult r = await built.ops.edit(
        key,
        argResults!['locale'] as String,
        value: argResults!['value'] as String?,
        isChecked: argResults!['checked'] as bool?,
        isPlaceholdersEnabled: placeholders == null ? null : true,
        placeholders: placeholders,
        dryRun: dryRun,
      );
      return emit(r);
    } finally {
      built.client.close();
    }
  }
}

class DeleteCommand extends Command<int> with _ApiCommand {
  DeleteCommand() {
    argParser.addOption('locale',
        help: 'Delete only this locale (default: the whole key, all locales).',);
  }

  @override
  String get name => 'delete';
  @override
  String get description => 'Delete a key (all locales) or a single locale.';
  @override
  String get invocation => 'fl delete <key> [--locale <code>]';

  @override
  Future<int> run() async {
    final String key = _requireKey(this);
    final ({ManagementClient client, Operations ops, String projectName}) built = await build(loadProject());
    try {
      final OpResult r = await built.ops.delete(
        key,
        locale: argResults!['locale'] as String?,
        dryRun: dryRun,
      );
      return emit(r);
    } finally {
      built.client.close();
    }
  }
}

class TranslateCommand extends Command<int> with _ApiCommand {
  TranslateCommand() {
    argParser.addFlag('all',
        negatable: false, help: 'Translate every non-base locale (default: only missing).',);
    argParser.addMultiOption('locale', help: 'Specific locale(s) to translate.');
  }

  @override
  String get name => 'translate';
  @override
  String get description => 'AI-translate a key\'s locales (default: only missing).';
  @override
  String get invocation => 'fl translate <key> [--all | --locale fr --locale de]';

  @override
  Future<int> run() async {
    final String key = _requireKey(this);
    final ({ManagementClient client, Operations ops, String projectName}) built = await build(loadProject());
    try {
      final OpResult r = await built.ops.translate(
        key,
        all: argResults!['all'] as bool,
        locales: argResults!['locale'] as List<String>,
        dryRun: dryRun,
      );
      return emit(r);
    } finally {
      built.client.close();
    }
  }
}

class StatusCommand extends Command<int> with _ApiCommand {
  @override
  String get name => 'status';
  @override
  String get description => 'Show completion % per locale.';

  @override
  Future<int> run() async {
    final ({ManagementClient client, Operations ops, String projectName}) built = await build(loadProject());
    try {
      final OpResult r = await built.ops.status();
      if (jsonOut) return emit(r);
      stdout.writeln(r.message);
      for (final row in (r.data['locales'] as List)) {
        final Map<String, dynamic> m = row as Map<String, dynamic>;
        final String tag = (m['base'] as bool) ? ' (base)' : '';
        stdout.writeln(
            '  ${m['locale']}$tag: ${m['filled']}/${m['total']} (${m['percent']}%)',);
      }
      return 0;
    } finally {
      built.client.close();
    }
  }
}

class PullCommand extends Command<int> with _ApiCommand {
  @override
  String get name => 'pull';
  @override
  String get description => 'git pull the ARB repo (arb_dir in config).';

  @override
  Future<int> run() async {
    final ProjectConfig cfg = loadProject();
    final String dir = cfg.arbDir ?? '.';
    stdout.writeln('Pulling ARBs in $dir …');
    final ProcessResult res =
        await Process.run('git', <String>['pull', '--rebase'], workingDirectory: dir);
    stdout.write(res.stdout);
    if (res.exitCode != 0) {
      stderr.write(res.stderr);
      return res.exitCode;
    }
    stdout.writeln('✓ Pulled.');
    return 0;
  }
}

String _requireKey(final Command<int> cmd) {
  final List<String> rest = cmd.argResults!.rest;
  if (rest.isEmpty) {
    throw UsageException('Missing <key> argument.', cmd.usage);
  }
  return rest.first;
}
