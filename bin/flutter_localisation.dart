import 'dart:io';
import 'package:logging/logging.dart';

final Logger _logger = Logger('LocalizationGenerator');

Future<void> main(List<String> args) async {
  _setupLogging();

  if (args.isEmpty) {
    _logger.severe('Please provide a flavor as an argument.');
    exit(1);
  }

  final flavor = args[0];
  final l10nFile = File('l10n.yaml');

  _logger.info('Generating localization files for flavor: $flavor');

  try {
    // Check if l10n.yaml exists, create it if it doesn't
    if (!await l10nFile.exists()) {
      _logger.info('l10n.yaml does not exist. Creating a new one.');
      await l10nFile.writeAsString('''
arb-dir: lib/l10n/$flavor
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
synthetic-package: false
''');
    }

    // Read the contents of the l10n.yaml file
    final l10nContent = await l10nFile.readAsString();
    _logger.info('Original l10n.yaml content:\n$l10nContent');

    // Replace the arb-dir line with the current flavor directory
    final updatedContent = l10nContent.replaceFirstMapped(
      RegExp(r'arb-dir: (.*)'),
      (match) => 'arb-dir: lib/l10n/$flavor',
    );

    _logger.info('Updated l10n.yaml content:\n$updatedContent');

    // Write the updated content to the l10n.yaml file
    await l10nFile.writeAsString(updatedContent);
    _logger.info('l10n.yaml file updated successfully.');

    // Run the flutter gen-l10n command
    final result = await Process.run('flutter', ['gen-l10n']);
    _logger.info(result.stdout);
    if (result.stderr.isNotEmpty) {
      _logger.severe('Error: ${result.stderr}');
      exit(1);
    }
  } catch (e) {
    _logger.severe('An error occurred: $e');
    exit(1);
  }
}

void _setupLogging() {
  Logger.root.level = Level.ALL; // Set logging level to all
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}
