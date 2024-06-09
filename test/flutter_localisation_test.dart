import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Localization Generator', () {
    final l10nFile = File('l10n.yaml');

    setUp(() async {
      // Write original content to the l10n.yaml file before each test
      final originalContent = '''
arb-dir: lib/l10n/aa
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
synthetic-package: false
''';
      await l10nFile.writeAsString(originalContent);
    });

    tearDown(() async {
      // Clean up after each test
      if (await l10nFile.exists()) {
        await _setReadOnly(l10nFile, false);
        await l10nFile.delete();
      }
      // Clean up any created directories
      final dir = Directory('lib/l10n/test_flavor');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('should update l10n.yaml with correct flavor', () async {
      final flavor = 'test_flavor';

      // Ensure the test flavor directory and ARB file exist
      final dir = Directory('lib/l10n/test_flavor');
      await dir.create(recursive: true);
      await File('lib/l10n/test_flavor/app_en.arb').writeAsString('{}');

      // Run the localization generator script
      final result = await Process.run(
          'dart', ['run', 'bin/flutter_localisation.dart', flavor]);

      // Ensure the script ran successfully
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');
      expect(result.exitCode, 0, reason: result.stderr);

      // Read the updated content
      final updatedContent = await l10nFile.readAsString();

      // Check if the arb-dir was correctly updated
      expect(updatedContent.contains('arb-dir: lib/l10n/$flavor'),
          isTrue); // Correctly use the actual value
    });

    test('should log an error if no flavor is provided', () async {
      // Run the localization generator script without arguments
      final result =
          await Process.run('dart', ['run', 'bin/flutter_localisation.dart']);

      // Ensure the script exits with an error
      expect(result.exitCode, isNot(0));

      // Check if the error message was logged
      final output = result.stdout + result.stderr;
      expect(output, contains('Please provide a flavor as an argument.'));
    });

    test('should handle errors during file reading and writing', () async {
      final flavor = 'test_flavor';

      // Simulate an error by making the l10n.yaml file read-only
      await l10nFile.writeAsString('arb-dir: lib/l10n/aa');
      await _setReadOnly(l10nFile, true);

      // Run the localization generator script
      final result = await Process.run(
          'dart', ['run', 'bin/flutter_localisation.dart', flavor]);

      // Log stdout and stderr for debugging
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');

      // Ensure the script exits with an error
      expect(result.exitCode, isNot(0));

      // Check if the error message was logged
      final output = result.stdout + result.stderr;
      expect(output, contains('An error occurred:'));

      // Clean up
      await _setReadOnly(l10nFile, false);
      await l10nFile.delete();
    });

    test('should create l10n.yaml from scratch if it does not exist', () async {
      final flavor = 'test_flavor';

      // Ensure l10n.yaml does not exist
      if (await l10nFile.exists()) {
        await l10nFile.delete();
      }

      // Ensure the test flavor directory and ARB file exist
      final dir = Directory('lib/l10n/test_flavor');
      await dir.create(recursive: true);
      await File('lib/l10n/test_flavor/app_en.arb').writeAsString('{}');

      // Run the localization generator script
      final result = await Process.run(
          'dart', ['run', 'bin/flutter_localisation.dart', flavor]);

      // Ensure the script ran successfully
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');
      expect(result.exitCode, 0, reason: result.stderr);

      // Check if l10n.yaml was created
      expect(await l10nFile.exists(), isTrue);

      // Read the updated content
      final updatedContent = await l10nFile.readAsString();

      // Check if the arb-dir was correctly updated
      expect(updatedContent.contains('arb-dir: lib/l10n/$flavor'), isTrue);
    });
  });
}

Future<void> _setReadOnly(File file, bool readOnly) async {
  final result =
      await Process.run('chmod', [readOnly ? '444' : '644', file.path]);
  if (result.exitCode != 0) {
    throw Exception('Failed to change file permissions: ${result.stderr}');
  }
}
