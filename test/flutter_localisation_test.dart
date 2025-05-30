import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  // ✅ SÉCURISÉ : Utiliser un dossier temporaire unique
  late Directory testDir;
  late File l10nFile;
  late String projectRoot;
  late String scriptPath;

  setUpAll(() async {
    // Sauvegarder le répertoire du projet
    projectRoot = Directory.current.path;
    scriptPath = path.join(projectRoot, 'bin', 'flutter_localisation.dart');

    // Vérifier que le script existe
    if (!await File(scriptPath).exists()) {
      throw Exception('Script not found: $scriptPath');
    }

    // Créer un dossier temporaire unique pour tous les tests
    final tempDir = Directory.systemTemp;
    final randomId = Random().nextInt(999999);
    testDir = Directory(
        path.join(tempDir.path, 'flutter_localisation_test_$randomId'));
    await testDir.create(recursive: true);

    print('🧪 Tests running in: ${testDir.path}');
    print('📄 Script path: $scriptPath');
  });

  tearDownAll(() async {
    // ✅ SÉCURISÉ : Supprimer seulement le dossier temporaire
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
      print('🧹 Cleaned up test directory: ${testDir.path}');
    }
  });

  setUp(() async {
    l10nFile = File(path.join(testDir.path, 'l10n.yaml'));

    // ✅ AJOUT : Créer un pubspec.yaml minimal pour les tests
    final pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
    await pubspecFile.writeAsString('''
name: test_project
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

flutter:
  generate: true  # ✅ IMPORTANT pour flutter gen-l10n
''');

    // Ensure l10n.yaml has default content
    await l10nFile.writeAsString('''
arb-dir: lib/l10n/default
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
synthetic-package: false
''');
  });

  tearDown(() async {
    // ✅ SÉCURISÉ : Nettoyer seulement les fichiers de test
    if (await l10nFile.exists()) {
      await _setReadOnly(l10nFile, false);
      await l10nFile.delete();
    }

    // Nettoyer le lib/ dans le dossier de test seulement
    final testLibDir = Directory(path.join(testDir.path, 'lib'));
    if (await testLibDir.exists()) {
      await testLibDir.delete(recursive: true);
    }
  });

  test('should update l10n.yaml with correct flavor', () async {
    final flavor = 'test_flavor';

    // Ensure the test flavor directory and ARB file exist
    final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the localization generator script
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    // Ensure the script ran successfully
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Read the updated content
    final updatedContent = await l10nFile.readAsString();

    // Check if the arb-dir was correctly updated
    expect(updatedContent.contains('arb-dir: lib/l10n/$flavor'), isTrue);
  });

  test('should log an error if no flavor is provided', () async {
    // Run the localization generator script without arguments
    final result = await Process.run(
      'dart',
      ['run', scriptPath],
      workingDirectory: testDir.path,
    );

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the error message was logged
    final output = result.stdout + result.stderr;
    expect(
      output,
      contains(
        'Usage: dart run flutter_localization <flavors-folder> <flavor-name>\nBoth arguments are required.',
      ),
    );
  });

  test('should handle errors during file reading and writing', () async {
    final flavor = 'test_flavor';

    // Simulate an error by making the l10n.yaml file read-only
    await l10nFile.writeAsString('arb-dir: lib/l10n/default');
    await _setReadOnly(l10nFile, true);

    // Run the localization generator script
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    // Log stdout and stderr for debugging
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the error message was logged
    final output = result.stdout + result.stderr;
    expect(output, contains('Invalid flavor folder: lib/l10n/test_flavor'));

    // Clean up
    await _setReadOnly(l10nFile, false);
  });

  test('should create l10n.yaml from scratch if it does not exist', () async {
    final flavor = 'test_flavor';

    // Ensure l10n.yaml does not exist
    if (await l10nFile.exists()) {
      await l10nFile.delete();
    }

    // Ensure the test flavor directory and ARB file exist
    final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the localization generator script
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

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
    final dir = Directory(path.join(testDir.path, 'lib/l10n/$flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the script
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    // Check script execution
    expect(result.exitCode, 0, reason: result.stderr);

    // Verify updated l10n.yaml content
    final updatedContent = await l10nFile.readAsString();
    expect(updatedContent, contains('arb-dir: lib/l10n/$flavor'));
  });

  test('Logs error if no flavor is provided', () async {
    // Run the script without arguments
    final result = await Process.run(
      'dart',
      ['run', scriptPath],
      workingDirectory: testDir.path,
    );

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
        'Usage: dart run flutter_localization <flavors-folder> <flavor-name>\nBoth arguments are required.',
      ),
    );
  });

  test('Handles invalid flavor folder gracefully', () async {
    final invalidFlavor = 'nonexistent_flavor';

    // Run the script with an invalid flavor
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', invalidFlavor],
      workingDirectory: testDir.path,
    );

    // Log stdout and stderr for debugging
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    print('Exit Code: ${result.exitCode}');

    // Verify the script exits with an error
    expect(
      result.exitCode,
      isNot(0),
      reason: 'Expected non-zero exit code for invalid flavor folder.',
    );

    // Verify error message contains the invalid folder
    final output = result.stdout + result.stderr;
    expect(
      output,
      contains('Invalid flavor folder: lib/l10n/$invalidFlavor'),
      reason: 'Expected error message for invalid flavor folder.',
    );
  });

  test('Overwrites existing l10n.yaml with new flavor', () async {
    final initialFlavor = 'flavor1';
    final newFlavor = 'flavor2';

    // Create the required directories
    final initialDir =
        Directory(path.join(testDir.path, 'lib/l10n/$initialFlavor'));
    final newDir = Directory(path.join(testDir.path, 'lib/l10n/$newFlavor'));
    await initialDir.create(recursive: true);
    await newDir.create(recursive: true);

    // Add a dummy ARB file for the new flavor
    await File(path.join(newDir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "hello_world": "Hello World"
}
''');

    // Ensure l10n.yaml exists with the initial flavor
    await l10nFile.writeAsString('arb-dir: lib/l10n/$initialFlavor');

    // Log the initial content for debugging
    print('Initial l10n.yaml content: ${await l10nFile.readAsString()}');

    // Run the script for the new flavor
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', newFlavor],
      workingDirectory: testDir.path,
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
      final dir = Directory(path.join(testDir.path, 'lib/l10n/$flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');
    }

    // Process both flavors
    for (var flavor in flavors) {
      final result = await Process.run(
        'dart',
        ['run', scriptPath, 'lib/l10n', flavor],
        workingDirectory: testDir.path,
      );
      expect(result.exitCode, 0);
    }

    // Verify files remain independent
    for (var flavor in flavors) {
      final arbFile =
          File(path.join(testDir.path, 'lib/l10n/$flavor/app_en.arb'));
      expect(await arbFile.exists(), isTrue);
    }
  });

  test('Ensures arb-dir path is updated correctly without duplication',
      () async {
    final flavorsFolder = 'lib/l10n';
    final flavor = 'test_flavor';

    // Ensure the test flavor directory and ARB file exist
    final dir = Directory(path.join(testDir.path, '$flavorsFolder/$flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the localization generator script
    final result = await Process.run(
      'dart',
      ['run', scriptPath, flavorsFolder, flavor],
      workingDirectory: testDir.path,
    );

    // Ensure the script ran successfully
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Read the updated l10n.yaml content
    final updatedContent = await l10nFile.readAsString();

    // Verify that arb-dir is set correctly
    final expectedPath = 'arb-dir: $flavorsFolder/$flavor';
    expect(
      updatedContent.contains(expectedPath),
      isTrue,
      reason: 'Expected arb-dir to be correctly updated to $expectedPath',
    );

    // Ensure we do not have incorrect duplicated paths like "lib/l10n/lib/l10n"
    expect(
      updatedContent.contains('arb-dir: $flavorsFolder/$flavorsFolder/$flavor'),
      isFalse,
      reason: 'arb-dir path should not be duplicated',
    );
  });

  group('Localization Generator (End-to-End)', () {
    late File groupL10nFile;
    late File arbEnFile;
    late File arbEsFile;
    late Directory generatedDir;

    setUp(() async {
      // ✅ SÉCURISÉ : Utiliser le dossier de test
      final l10nDir =
          Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await l10nDir.create(recursive: true);

      groupL10nFile = File(path.join(testDir.path, 'l10n.yaml'));
      arbEnFile = File(path.join(l10nDir.path, 'app_en.arb'));
      arbEsFile = File(path.join(l10nDir.path, 'app_es.arb'));
      generatedDir =
          Directory(path.join(testDir.path, 'lib/localization/generated'));

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
      await groupL10nFile.writeAsString('''
arb-dir: lib/l10n/test_flavor
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
synthetic-package: false
''');
    });

    tearDown(() async {
      // ✅ SÉCURISÉ : Nettoyer seulement dans le dossier de test
      final testLibDir = Directory(path.join(testDir.path, 'lib'));
      if (await testLibDir.exists()) {
        await testLibDir.delete(recursive: true);
      }

      if (await groupL10nFile.exists()) {
        await groupL10nFile.delete();
      }
    });

    test('Generates translations and updates correctly', () async {
      // Run the localization generator script
      final result = await Process.run(
        'dart',
        ['run', scriptPath, 'lib/l10n', 'test_flavor'],
        workingDirectory: testDir.path,
      );

      // Verify script ran successfully
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');
      expect(result.exitCode, 0, reason: 'Script execution failed.');

      // Verify Spanish and English localization files exist
      final enGeneratedFile = File(
        path.join(generatedDir.path, 'app_localizations_en.dart'),
      );
      final esGeneratedFile = File(
        path.join(generatedDir.path, 'app_localizations_es.dart'),
      );
      expect(
        await enGeneratedFile.exists(),
        isTrue,
        reason: 'English localization file not found.',
      );
      expect(
        await esGeneratedFile.exists(),
        isTrue,
        reason: 'Spanish localization file not found.',
      );

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
  final result = await Process.run('chmod', [
    readOnly ? '444' : '644',
    file.path,
  ]);
  if (result.exitCode != 0) {
    throw Exception('Failed to change file permissions: ${result.stderr}');
  }
}
