import 'dart:io';

import 'package:logging/logging.dart';

final Logger _logger = Logger('LocalizationGenerator');

Future<void> main(List<String> args) async {
  _setupLogging();

  if (args.length < 2) {
    _logger.severe(
      'Usage: dart run flutter_localization <flavors-folder> <flavor-name>\nBoth arguments are required.',
    );
    exit(1);
  }

  final flavorsFolder = args[0];
  final flavor = args[1];
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
  } catch (e) {
    _logger.severe('An error occurred: $e');
    exit(1);
  }
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
