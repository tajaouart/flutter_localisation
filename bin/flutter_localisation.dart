import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final Logger _logger = Logger('LocalizationGenerator');

Future<void> main(List<String> args) async {
  _setupLogging();

  if (args.length < 2) {
    _logger.severe(
      'Usage: dart run flutter_localization <flavors-folder> <flavor-name> [--with-saas]\n'
      'Both arguments are required.\n'
      'Add --with-saas to also generate SaaS methods automatically.',
    );
    exit(1);
  }

  final flavorsFolder = args[0];
  final flavor = args[1];
  final withSaas = args.contains('--with-saas');
  final l10nFile = File('l10n.yaml');

  _logger.info(
    'Generating localization files for flavor: $flavor, using flavors folder: $flavorsFolder',
  );

  try {
    // Validate the flavor folder exists
    final flavorDirectory = Directory('$flavorsFolder/$flavor');
    if (!await flavorDirectory.exists()) {
      _logger.severe('Invalid flavor folder: $flavorsFolder/$flavor');
      exit(1);
    }

    // Validate or create the l10n.yaml file
    await _ensureL10nFile(l10nFile, flavorsFolder, flavor);

    // Validate ARB files exist in the flavor directory
    final arbFiles = await _getArbFiles(flavorDirectory);
    if (arbFiles.isEmpty) {
      _logger.severe(
        'No ARB files found in flavor folder: $flavorsFolder/$flavor',
      );
      exit(1);
    }

    _logger.info('Found ARB files: ${arbFiles.map((f) => f.path).join(', ')}');

    // Run the flutter gen-l10n command to generate localization
    final result = await Process.run('flutter', ['gen-l10n']);
    _logger.info('Flutter gen-l10n output:\n${result.stdout}');

    if (result.stderr.isNotEmpty) {
      _logger.severe('Error during localization generation: ${result.stderr}');
      exit(1);
    }

    _logger.info('Localization generation completed successfully.');

    // ✅ NOUVEAU: Si --with-saas, lancer generate.dart automatiquement
    if (withSaas) {
      _logger.info('🎯 Starting SaaS methods generation...');
      await _runSaaSGeneration();
    } else {
      _logger.info(
          '💡 Tip: Add --with-saas to also generate SaaS methods automatically');
    }
  } catch (e) {
    _logger.severe('An error occurred: $e');
    exit(1);
  }
}

Future<void> _runSaaSGeneration() async {
  try {
    // First, try the new approach with package executable
    _logger.info('🔧 Running: dart run flutter_localisation:generate');

    final packageResult = await Process.run(
      'dart',
      ['run', 'flutter_localisation:generate'],
      workingDirectory: _findProjectRoot() ?? Directory.current.path,
    );

    // If package approach works, we're done
    if (packageResult.exitCode == 0) {
      _logger.info('📤 SaaS generation stdout: ${packageResult.stdout}');
      if (packageResult.stderr.isNotEmpty) {
        _logger.warning('📤 SaaS generation stderr: ${packageResult.stderr}');
      }
      _logger.info('✅ SaaS methods generated successfully!');
      return;
    }

    // If package approach failed, fall back to the old file-based approach
    if (packageResult.stderr.toString().contains('Could not find package')) {
      _logger
          .info('Package executable not found, trying direct file approach...');

      // Use the old working code
      final possiblePaths = [
        'bin/generate.dart',
        '../bin/generate.dart',
        'packages/flutter_localisation/bin/generate.dart',
      ];

      String? generateScript;
      for (final path in possiblePaths) {
        if (await File(path).exists()) {
          generateScript = path;
          break;
        }
      }

      if (generateScript == null) {
        _logger.warning(
            '❌ SaaS generation script not found in any of these locations:');
        for (final path in possiblePaths) {
          _logger.warning('   - $path');
        }
        _logger.info(
            '💡 Skipping SaaS method generation. Run "saas_generate" manually if needed.');
        return;
      }

      _logger.info('📄 Found SaaS script: $generateScript');
      _logger.info('🔧 Running: dart run $generateScript');

      final fileResult = await Process.run('dart', ['run', generateScript]);

      _logger.info('📤 SaaS generation stdout: ${fileResult.stdout}');
      if (fileResult.stderr.isNotEmpty) {
        _logger.warning('📤 SaaS generation stderr: ${fileResult.stderr}');
      }

      if (fileResult.exitCode == 0) {
        _logger.info('✅ SaaS methods generated successfully!');
      } else {
        _logger.severe(
            '❌ SaaS generation failed with exit code: ${fileResult.exitCode}');
        _logger.severe('Error output: ${fileResult.stderr}');
        exit(1);
      }
    } else {
      // Package was found but failed for another reason
      _logger.info('📤 SaaS generation stdout: ${packageResult.stdout}');
      _logger.warning('📤 SaaS generation stderr: ${packageResult.stderr}');
      _logger.severe(
          '❌ SaaS generation failed with exit code: ${packageResult.exitCode}');
      exit(1);
    }
  } catch (e) {
    _logger.severe('💥 Exception during SaaS generation: $e');
    exit(1);
  }
}

String? _findProjectRoot() {
  var directory = Directory.current;

  while (directory.path != directory.parent.path) {
    final pubspecFile = File(path.join(directory.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      return directory.path;
    }
    directory = directory.parent;
  }
  return null;
}

Future<void> _ensureL10nFile(
  File l10nFile,
  String flavorsFolder,
  String flavor,
) async {
  if (!await l10nFile.exists()) {
    _logger.info('l10n.yaml does not exist. Creating a new one.');
    await l10nFile.writeAsString('''
arb-dir: $flavorsFolder/$flavor
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
synthetic-package: false
nullable-getter: false
use-escaping: true
''');
    return;
  }

  final l10nContent = await l10nFile.readAsString();
  _logger.info('Original l10n.yaml content:\n$l10nContent');

  final updatedContent = l10nContent.replaceFirstMapped(
    RegExp(r'arb-dir:.*'),
    (match) =>
        'arb-dir: ${flavorsFolder.replaceAll(RegExp(r'/$'), '')}/$flavor',
  );

  _logger.info('Updated l10n.yaml content:\n$updatedContent');
  await l10nFile.writeAsString(updatedContent);
  _logger.info('l10n.yaml file updated successfully.');
}

Future<List<File>> _getArbFiles(Directory flavorDirectory) async {
  // List all files in the directory and filter for .arb files
  final files = await flavorDirectory.list(recursive: false).toList();
  return files
      .whereType<File>()
      .where((file) => file.path.endsWith('.arb'))
      .toList();
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}
