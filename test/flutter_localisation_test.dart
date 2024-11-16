import 'dart:io';

import 'package:test/test.dart';

void main() {
  final l10nFile = File('l10n.yaml');

  setUp(() async {
    // Ensure l10n.yaml has default content
    await l10nFile.writeAsString('''
arb-dir: lib/l10n/default
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
synthetic-package: false
''');
  });

  tearDown(() async {
    if (await l10nFile.exists()) {
      await _setReadOnly(l10nFile, false);
      await l10nFile.delete();
    }
    final dir = Directory('lib/');
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
        'dart', ['run', 'bin/flutter_localisation.dart', 'lib/l10n', flavor]);

    // Ensure the script ran successfully
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Read the updated content
    final updatedContent = await l10nFile.readAsString();

    // Check if the arb-dir was correctly updated
    expect(
      updatedContent.contains('arb-dir: lib/l10n/$flavor'),
      isTrue,
    );
  });

  test('should log an error if no flavor is provided', () async {
    // Run the localization generator script without arguments
    final result =
        await Process.run('dart', ['run', 'bin/flutter_localisation.dart']);

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the error message was logged
    final output = result.stdout + result.stderr;
    expect(
      output,
      contains(
          'Please provide both the flavors folder and the flavor name as arguments.'),
    );
  });

  test('should handle errors during file reading and writing', () async {
    final flavor = 'test_flavor';

    // Simulate an error by making the l10n.yaml file read-only
    await l10nFile.writeAsString('arb-dir: lib/l10n/default');
    await _setReadOnly(l10nFile, true);

    // Run the localization generator script
    final result = await Process.run(
        'dart', ['run', 'bin/flutter_localisation.dart', 'lib/l10n', flavor]);

    // Log stdout and stderr for debugging
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the error message was logged
    final output = result.stdout + result.stderr;
    // Update to check for the correct error message
    expect(output, contains('Invalid flavor folder: lib/l10n/test_flavor'));

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
        'dart', ['run', 'bin/flutter_localisation.dart', 'lib/l10n', flavor]);

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

  test('Updates l10n.yaml with correct flavor', () async {
    final flavor = 'test_flavor';

    // Create test flavor directory and dummy ARB file
    await Directory('lib/l10n/$flavor').create(recursive: true);
    await File('lib/l10n/$flavor/app_en.arb').writeAsString('{}');

    // Run the script
    final result = await Process.run(
        'dart', ['run', 'bin/flutter_localisation.dart', 'lib/l10n', flavor]);

    // Check script execution
    expect(result.exitCode, 0, reason: result.stderr);

    // Verify updated l10n.yaml content
    final updatedContent = await l10nFile.readAsString();
    expect(updatedContent, contains('arb-dir: lib/l10n/$flavor'));
  });

  test('Logs error if no flavor is provided', () async {
    // Run the script without arguments
    final result =
        await Process.run('dart', ['run', 'bin/flutter_localisation.dart']);

    // Debug outputs
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    print('Exit Code: ${result.exitCode}');

    // Verify error status and message
    expect(result.exitCode, isNot(0));
    final output = result.stdout + result.stderr;
    expect(
      output,
      contains(
          'Please provide both the flavors folder and the flavor name as arguments.'),
    );
  });

  test('Handles invalid flavor folder gracefully', () async {
    final invalidFlavor = 'nonexistent_flavor';

    // Ensure the flavor directory does not exist
    final invalidDir = Directory('lib/l10n/$invalidFlavor');
    if (await invalidDir.exists()) {
      await invalidDir.delete(recursive: true);
    }

    // Run the script with an invalid flavor
    final result = await Process.run(
      'dart',
      ['run', 'bin/flutter_localisation.dart', 'lib/l10n', invalidFlavor],
    );

    // Log stdout and stderr for debugging
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    print('Exit Code: ${result.exitCode}');

    // Verify the script exits with an error
    expect(result.exitCode, isNot(0),
        reason: 'Expected non-zero exit code for invalid flavor folder.');

    // Verify error message contains the invalid folder
    final output = result.stdout + result.stderr; // Combine both streams
    expect(
      output,
      contains('Invalid flavor folder: lib/l10n/$invalidFlavor'),
      reason: 'Expected error message for invalid flavor folder.',
    );
  });

  test('Creates missing ARB file with default content', () async {
    final flavor = 'new_flavor';

    // Create flavor directory without ARB file
    final dir = Directory('lib/l10n/$flavor');
    await dir.create(recursive: true);
    final arbFile = File('lib/l10n/$flavor/app_en.arb');
    if (await arbFile.exists()) await arbFile.delete();

    // Run the script
    final result = await Process.run(
        'dart', ['run', 'bin/flutter_localisation.dart', 'lib/l10n', flavor]);

    // Verify ARB file creation and content
    expect(result.exitCode, 0);
    expect(await arbFile.exists(), isTrue);
    final content = await arbFile.readAsString();
    expect(content, contains('{"app_en": ""}')); // Default content check
  });

  test('Overwrites existing l10n.yaml with new flavor', () async {
    final initialFlavor = 'flavor1';
    final newFlavor = 'flavor2';

    // Create the required directories
    final initialDir = Directory('lib/l10n/$initialFlavor');
    final newDir = Directory('lib/l10n/$newFlavor');
    await initialDir.create(recursive: true);
    await newDir.create(recursive: true);

    // Ensure l10n.yaml exists with the initial flavor
    await l10nFile.writeAsString('arb-dir: lib/l10n/$initialFlavor');

    // Log the initial content for debugging
    print('Initial l10n.yaml content: ${await l10nFile.readAsString()}');

    // Run the script for the new flavor
    final result = await Process.run(
      'dart',
      ['run', 'bin/flutter_localisation.dart', 'lib/l10n', newFlavor],
    );

    // Log stdout, stderr, and exit code for debugging
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    print('Exit Code: ${result.exitCode}');

    // Verify the script ran successfully
    expect(
      result.exitCode,
      0,
      reason: 'Expected exit code 0 for successful update.',
    );

    // Verify the l10n.yaml file has been updated with the new flavor
    final updatedContent = await l10nFile.readAsString();
    print('Updated l10n.yaml content: $updatedContent');
    expect(
      updatedContent,
      contains('arb-dir: lib/l10n/$newFlavor'),
      reason: 'Expected arb-dir to be updated to the new flavor.',
    );

    // Verify the old flavor was replaced
    expect(
      updatedContent,
      isNot(contains('arb-dir: lib/l10n/$initialFlavor')),
      reason: 'Expected old flavor to be replaced in l10n.yaml.',
    );
  });
  test('Handles multiple flavors independently', () async {
    final flavors = ['flavor1', 'flavor2'];

    // Create directories and ARB files for both flavors
    for (var flavor in flavors) {
      final dir = Directory('lib/l10n/$flavor');
      await dir.create(recursive: true);
      await File('lib/l10n/$flavor/app_en.arb').writeAsString('{}');
    }

    // Process both flavors
    for (var flavor in flavors) {
      final result = await Process.run(
          'dart', ['run', 'bin/flutter_localisation.dart', 'lib/l10n', flavor]);
      expect(result.exitCode, 0);
    }

    // Verify files remain independent
    for (var flavor in flavors) {
      final arbFile = File('lib/l10n/$flavor/app_en.arb');
      expect(await arbFile.exists(), isTrue);
    }
  });

  group('Localization Generator (End-to-End)', () {
    late File l10nFile;
    late File arbEnFile;
    late File arbEsFile;
    final generatedDir = Directory('lib/localization/generated');

    setUp(() async {
      // Ensure directories exist
      final l10nDir = Directory('lib/l10n/test_flavor');
      if (!await l10nDir.exists()) {
        await l10nDir.create(recursive: true);
      }

      l10nFile = File('l10n.yaml');
      arbEnFile = File('lib/l10n/test_flavor/app_en.arb');
      arbEsFile = File('lib/l10n/test_flavor/app_es.arb');

      // Write ARB files (English and Spanish)
      await arbEnFile.writeAsString('''
{
  "@@locale": "en",
  "hello_world": "Hello World"
}
''');
      await arbEsFile.writeAsString('''
{
  "@@locale": "es",
  "hello_world": "Hola el mundo"
}
''');

      // Write initial l10n.yaml
      await l10nFile.writeAsString('''
arb-dir: lib/l10n/test_flavor
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
synthetic-package: false
''');
    });

    tearDown(() async {
      // Delete the entire lib directory recursively
      final libDir = Directory('lib');
      if (await libDir.exists()) {
        await libDir.delete(recursive: true);
      }

      // Clean up l10n.yaml if it exists
      if (await l10nFile.exists()) {
        await l10nFile.delete();
      }
    });

    test('Generates translations and updates correctly', () async {
      // Run the localization generator script
      final scriptPath =
          '${Directory.current.path}/bin/flutter_localisation.dart';
      final result = await Process.run(
        'dart',
        ['run', scriptPath, 'lib/l10n', 'test_flavor'],
      );

      // Verify script ran successfully
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');
      expect(result.exitCode, 0, reason: 'Script execution failed.');

      // Verify Spanish and English localization files exist
      final enGeneratedFile =
          File('${generatedDir.path}/app_localizations_en.dart');
      final esGeneratedFile =
          File('${generatedDir.path}/app_localizations_es.dart');
      expect(await enGeneratedFile.exists(), isTrue,
          reason: 'English localization file not found.');
      expect(await esGeneratedFile.exists(), isTrue,
          reason: 'Spanish localization file not found.');

      // Verify Spanish translation exists in the generated file
      final esGeneratedContent = await esGeneratedFile.readAsString();
      expect(
        esGeneratedContent,
        contains('Hola el mundo'),
        reason:
            'Expected Spanish translation to be included in the generated file.',
      );

      // Verify English translation exists in the generated file
      final enGeneratedContent = await enGeneratedFile.readAsString();
      expect(
        enGeneratedContent,
        contains('Hello World'),
        reason:
            'Expected English translation to be included in the generated file.',
      );
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
