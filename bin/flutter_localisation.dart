import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final Logger _logger = Logger('LocalizationGenerator');

Future<void> main(final List<String> args) async {
  _setupLogging();

  if (args.length < 2) {
    _logger.severe(
        'Usage: dart run flutter_localisation <flavors-folder> <flavor-name>\n'
        'Both arguments are required.');
    exit(1);
  }

  final String flavorsFolder = args[0];
  final String flavor = args[1];
  final File l10nFile = File('l10n.yaml');

  _logger.info(
    'Generating localization files for flavor: $flavor, using flavors folder: $flavorsFolder',
  );

  try {
    // Pull latest changes from Git if the flavors folder is a Git repository
    await _pullLatestChanges(flavorsFolder);

    // Validate the flavor folder exists
    final Directory flavorDirectory = Directory('$flavorsFolder/$flavor');
    if (!await flavorDirectory.exists()) {
      _logger.severe('Invalid flavor folder: $flavorsFolder/$flavor');
      exit(1);
    }

    // Validate or create the l10n.yaml file
    await _ensureL10nFile(l10nFile, flavorsFolder, flavor);

    // Validate ARB files exist in the flavor directory
    final List<File> arbFiles = await _getArbFiles(flavorDirectory);
    if (arbFiles.isEmpty) {
      _logger.severe(
        'No ARB files found in flavor folder: $flavorsFolder/$flavor',
      );
      exit(1);
    }

    _logger.info(
      'Found ARB files: ${arbFiles.map((final File f) => path.basename(f.path)).join(', ')}',
    );

    // Run the flutter gen-l10n command to generate localization
    final ProcessResult result =
        await Process.run('flutter', <String>['gen-l10n']);

    final String stdoutStr = result.stdout as String;
    final String stderrStr = result.stderr as String;

    _logger.info('Flutter gen-l10n output:\n$stdoutStr');

    if (stderrStr.isNotEmpty &&
        !stderrStr.contains('Because l10n.yaml exists')) {
      _logger.severe('Error during localization generation: $stderrStr');
      exit(1);
    }

    _logger.info('Localization generation completed successfully.');

    _logger.info('🎯 Starting FlutterLocalisation methods generation...');
    await _runGeneration();
  } on Exception catch (e) {
    _logger.severe('An error occurred: $e');
    exit(1);
  }
}

Future<void> _runGeneration() async {
  try {
    // ==== CHANGE START: Prioritize local development paths ====
    // Method 1 (Previously 4): Fallback to local paths (for development)
    // This is now checked FIRST to allow local overrides and for testing.
    _logger.info('🔍 Checking local development paths...');
    final List<String> localPaths = <String>[
      'bin/generate.dart',
      '../bin/generate.dart',
      'packages/flutter_localisation/bin/generate.dart',
    ];

    for (final String scriptPath in localPaths) {
      if (File(scriptPath).existsSync()) {
        _logger.info('📄 Found local generate script: $scriptPath');

        final ProcessResult result = await Process.run(
          'dart',
          <String>[scriptPath], // Execute directly, not with 'run'
          workingDirectory: Directory.current.path,
        );

        if (result.exitCode == 0) {
          // Output the result so mock scripts' print statements appear
          if (result.stdout.toString().isNotEmpty) {
            print(result.stdout);
          }
          _logger.info('✅ FlutterLocalisation methods generated successfully!');
          return; // Exit after successful local script execution
        } else {
          _logger.warning('⚠️ Local generate script failed: ${result.stderr}');
          // We will now fall through to other methods if the local script fails.
        }
      }
    }
    // ==== CHANGE END ====

    // Method 2 (Previously 1): Try as a package executable
    _logger.info('📦 Attempting to run as package executable...');
    final ProcessResult packageResult = await Process.run(
      'dart',
      <String>['run', 'flutter_localisation:generate'],
      workingDirectory: Directory.current.path,
    );

    if (packageResult.exitCode == 0) {
      _logger.info(
        '✅ FlutterLocalisation methods generated successfully via package!',
      );
      return;
    }

    // Method 3 (Previously 2): Try to find the package in .dart_tool/package_config.json
    _logger.info('🔍 Looking for package in .dart_tool...');
    final File packageConfig = File('.dart_tool/package_config.json');
    if (packageConfig.existsSync()) {
      try {
        final String configContent = await packageConfig.readAsString();
        // Simple regex to find flutter_localisation package path
        final RegExp packagePathRegex = RegExp(
          r'"name"\s*:\s*"flutter_localisation"[^}]*"rootUri"\s*:\s*"([^"]+)"',
          multiLine: true,
        );
        final RegExpMatch? match = packagePathRegex.firstMatch(configContent);

        if (match != null) {
          String packagePath = match.group(1)!;
          // Handle file:// URIs
          if (packagePath.startsWith('file://')) {
            packagePath = packagePath.substring(7);
          }
          // Handle relative paths
          if (packagePath.startsWith('../')) {
            packagePath =
                path.normalize(path.join(Directory.current.path, packagePath));
          }

          final String generateScriptPath =
              path.join(packagePath, 'bin', 'generate.dart');
          if (File(generateScriptPath).existsSync()) {
            _logger.info('📄 Found generate script at: $generateScriptPath');

            final ProcessResult result = await Process.run(
              'dart',
              <String>['run', generateScriptPath],
              workingDirectory: Directory.current.path,
            );

            if (result.exitCode == 0) {
              _logger.info(
                '✅ FlutterLocalisation methods generated successfully!',
              );
              return;
            } else {
              _logger.warning('⚠️ Generate script failed: ${result.stderr}');
            }
          }
        }
      } on Exception catch (e) {
        _logger.warning('Could not parse package config: $e');
      }
    }

    // Method 4 (Previously 3): Look in pub cache
    _logger.info('🔍 Looking in pub cache...');
    final String pubCachePath = Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows
            ? path.join(Platform.environment['APPDATA']!, 'Pub', 'Cache')
            : path.join(Platform.environment['HOME']!, '.pub-cache'));

    // Remove the null check since pubCachePath is always non-null
    final Directory hostedDir =
        Directory(path.join(pubCachePath, 'hosted', 'pub.dev'));
    if (hostedDir.existsSync()) {
      final Directory hostedDir =
          Directory(path.join(pubCachePath, 'hosted', 'pub.dev'));
      if (hostedDir.existsSync()) {
        final List<FileSystemEntity> packages = hostedDir
            .listSync()
            .where(
              (final FileSystemEntity entity) => path
                  .basename(entity.path)
                  .startsWith('flutter_localisation-'),
            )
            .toList();

        if (packages.isNotEmpty) {
          // Sort to get the latest version
          packages.sort(
            (final FileSystemEntity a, final FileSystemEntity b) {
              return b.path.compareTo(a.path);
            },
          );
          final String packagePath = packages.first.path;
          final String generateScriptPath =
              path.join(packagePath, 'bin', 'generate.dart');

          if (File(generateScriptPath).existsSync()) {
            _logger.info(
              '📄 Found generate script in pub cache: $generateScriptPath',
            );

            final ProcessResult result = await Process.run(
              'dart',
              <String>['run', generateScriptPath],
              workingDirectory: Directory.current.path,
            );

            if (result.exitCode == 0) {
              _logger.info(
                '✅ FlutterLocalisation methods generated successfully!',
              );
              return;
            }
          }
        }
      }
    }

    // If we get here, we couldn't find or run the generate script
    _logger.warning('⚠️ Could not find or run the generate.dart script.');
    _logger.warning(
      'The package is installed but the generation script is not accessible.',
    );
    _logger
        .warning('This may happen if the package is not properly configured.');
    _logger.info(
      '💡 The localization files have been generated, but the helper methods were not created.',
    );
    _logger.info('💡 You can manually run the generation script if needed.');
  } on Exception catch (e) {
    _logger.severe('💥 Exception during FlutterLocalisation generation: $e');
    // Don't exit here - the main localization was successful
    _logger.info(
      '⚠️ Main localization was successful, continuing despite generation error.',
    );
  }
}

Future<void> _pullLatestChanges(final String flavorsFolder) async {
  final Directory arbsDirectory = Directory(flavorsFolder);
  final Directory gitDirectory = Directory(path.join(flavorsFolder, '.git'));

  // Check if the flavors folder exists
  if (!await arbsDirectory.exists()) {
    _logger.warning(
      '⚠️ Flavors folder "$flavorsFolder" does not exist. Skipping git pull.',
    );
    return;
  }

  // Check if it's a git repository
  if (!await gitDirectory.exists()) {
    _logger.info(
      '📁 "$flavorsFolder" is not a Git repository. Skipping git pull.',
    );
    return;
  }

  _logger.info('🔄 Pulling latest changes from Git in "$flavorsFolder"...');

  try {
    final ProcessResult result = await Process.run(
      'git',
      <String>['pull'],
      workingDirectory: arbsDirectory.path,
    );

    final String stdout = result.stdout as String;
    final String stderr = result.stderr as String;

    if (result.exitCode == 0) {
      _logger.info('✅ Git pull successful!');
      if (stdout.trim().isNotEmpty) {
        _logger.info('Git output: ${stdout.trim()}');
      }
    } else {
      _logger.warning('⚠️ Git pull failed with exit code ${result.exitCode}');
      if (stderr.trim().isNotEmpty) {
        _logger.warning('Error: ${stderr.trim()}');
      }
      _logger.info('Continuing with current ARB files...');
    }
  } on Exception catch (e) {
    _logger.warning('⚠️ Failed to run git pull: $e');
    _logger.info('Continuing with current ARB files...');
  }
}

Future<void> _ensureL10nFile(
  final File l10nFile,
  final String flavorsFolder,
  final String flavor,
) async {
  if (!await l10nFile.exists()) {
    _logger.info('l10n.yaml does not exist. Creating a new one.');
    await l10nFile.writeAsString('''
arb-dir: $flavorsFolder/$flavor
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
nullable-getter: false
use-escaping: true
''');
    return;
  }

  final String l10nContent = await l10nFile.readAsString();
  _logger.info('Original l10n.yaml content:\n$l10nContent');

  final String updatedContent = l10nContent.replaceFirstMapped(
    RegExp(r'arb-dir:.*'),
    (final Match match) =>
        'arb-dir: ${flavorsFolder.replaceAll(RegExp(r'/$'), '')}/$flavor',
  );

  _logger.info('Updated l10n.yaml content:\n$updatedContent');
  await l10nFile.writeAsString(updatedContent);
  _logger.info('l10n.yaml file updated successfully.');
}

Future<List<File>> _getArbFiles(final Directory flavorDirectory) async {
  // List all files in the directory and filter for .arb files
  final List<FileSystemEntity> files = await flavorDirectory.list().toList();
  return files
      .whereType<File>()
      .where((final File file) => file.path.endsWith('.arb'))
      .toList();
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((final LogRecord record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}
