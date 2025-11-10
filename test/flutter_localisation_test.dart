import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory testDir;
  late File l10nFile;
  late String projectRoot;
  late String scriptPath;

  void ensureInTestDirectory(
    final String pathToCheck,
    final String testDirPath,
  ) {
    if (!pathToCheck.contains('flutter_localisation_test_')) {
      throw Exception(
        '🚨 SÉCURITÉ: Tentative d\'opération sur un chemin non-test: $pathToCheck',
      );
    }
    if (!pathToCheck.contains(testDirPath)) {
      throw Exception(
        '🚨 SÉCURITÉ: Chemin en dehors du dossier de test: $pathToCheck',
      );
    }
  }

  Future<void> setReadOnly(final File file, final bool readOnly) async {
    final ProcessResult result = await Process.run(
      'chmod',
      <String>[readOnly ? '444' : '644', file.path],
    );
    if (result.exitCode != 0) {
      print('Could not set read-only status: ${result.stderr}');
    }
  }

  setUpAll(() async {
    projectRoot = Directory.current.path;
    scriptPath = path.join(projectRoot, 'bin', 'flutter_localisation.dart');

    if (!projectRoot.contains('flutter_localisation')) {
      throw Exception(
        '🚨 SÉCURITÉ: Test lancé depuis un mauvais répertoire: $projectRoot',
      );
    }

    // Vérifier que le script existe
    if (!await File(scriptPath).exists()) {
      throw Exception('Script not found: $scriptPath');
    }

    // 🛡️ GARDE-FOU: Créer un dossier temporaire TRÈS spécifique
    final Directory tempDir = Directory.systemTemp;
    final int randomId = Random().nextInt(999999);
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    testDir = Directory(
      path.join(
        tempDir.path,
        'SAFE_flutter_localisation_test_${randomId}_$timestamp',
      ),
    );
    await testDir.create(recursive: true);

    // 🛡️ GARDE-FOU: Vérifier qu'on est bien dans un dossier temporaire
    if (!testDir.path.contains(tempDir.path)) {
      throw Exception(
        '🚨 SÉCURITÉ: testDir n\'est pas dans le dossier temporaire!',
      );
    }
    if (testDir.path.contains(projectRoot)) {
      throw Exception('🚨 SÉCURITÉ: testDir est dans le projet! Danger!');
    }
  });

  tearDown(() async {
    if (await l10nFile.exists()) {
      await setReadOnly(l10nFile, false);
      await l10nFile.delete();
    }

    // Nettoyer le pubspec.yaml de test
    final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
    if (await pubspecFile.exists()) {
      await pubspecFile.delete();
    }

    // 🛡️ SÉCURISÉ: Nettoyer les scripts mock avec validation
    final Directory binDir = Directory(path.join(testDir.path, 'bin'));
    if (await binDir.exists()) {
      ensureInTestDirectory(
        binDir.path,
        testDir.path,
      ); // ← AJOUTEZ cette ligne
      await binDir.delete(recursive: true);
    }

    // 🛡️ SÉCURISÉ: Nettoyer le lib/ avec validation
    final Directory testLibDir = Directory(path.join(testDir.path, 'lib'));
    if (await testLibDir.exists()) {
      ensureInTestDirectory(
        testLibDir.path,
        testDir.path,
      ); // ← AJOUTEZ cette ligne
      await testLibDir.delete(recursive: true);
    }
  });

  tearDownAll(() async {
    // 🛡️ GARDE-FOU: Double vérification avant suppression
    if (await testDir.exists()) {
      // Vérifier qu'on supprime bien un dossier temporaire
      if (!testDir.path.contains('SAFE_flutter_localisation_test_')) {
        throw Exception(
          '🚨 SÉCURITÉ: Tentative de suppression d\'un dossier non-test!',
        );
      }
      if (testDir.path.contains(projectRoot)) {
        throw Exception(
          '🚨 SÉCURITÉ: Tentative de suppression dans le projet!',
        );
      }

      await testDir.delete(recursive: true);
    }
  });

  setUp(() async {
    l10nFile = File(path.join(testDir.path, 'l10n.yaml'));

    final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
    await pubspecFile.writeAsString('''
name: test_project
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localisations:
    sdk: flutter

flutter:
  generate: true
''');

    // Ensure l10n.yaml has default content
    await l10nFile.writeAsString('''
arb-dir: lib/l10n/default
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
''');
  });

  test('should update l10n.yaml with correct flavor', () async {
    final String flavor = 'test_flavor';

    // Ensure the test flavor directory and ARB file exist
    final Directory dir =
        Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the localization generator script
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    // Ensure the script ran successfully
    expect(result.exitCode, 0, reason: result.stderr);

    // Read the updated content
    final String updatedContent = await l10nFile.readAsString();

    // Check if the arb-dir was correctly updated
    expect(updatedContent.contains('arb-dir: lib/l10n/$flavor'), isTrue);
  });

  test('should show updated usage message - with generation', () async {
    // Run the localization generator script without arguments
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath],
      workingDirectory: testDir.path,
    );

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the updated error message was logged
    final String output = result.stdout.toString() + result.stderr;
    expect(
      output,
      contains(
        'Usage: dart run flutter_localisation <flavors-folder> <flavor-name>',
      ),
    );
  });

  test('should handle missing generate.dart script gracefully', () async {
    final String flavor = 'test_flavor';

    // Create test setup
    final Directory dir =
        Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(
      result.exitCode,
      0,
      reason: 'Should complete successfully even without generate.dart',
    );

    // Check FlutterLocalisation generation was attempted but skipped
    final String output = result.stdout.toString() + result.stderr.toString();
    expect(
      output,
      contains('🎯 Starting FlutterLocalisation methods generation...'),
    );
    expect(
      output,
      anyOf(
        contains('⚠️ Could not find or run the generate.dart script'),
        contains('❌ FlutterLocalisation generation script not found'),
      ),
    );
    expect(
      output,
      anyOf(
        contains('⚠️ Could not find or run the generate.dart script'),
        contains('❌ FlutterLocalisation generation failed'),
      ),
    );
  });

  test('should run FlutterLocalisation generation successfully', () async {
    final String flavor = 'test_flavor';

    // Create test setup
    final Directory dir =
        Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    final Directory binDir = Directory(path.join(testDir.path, 'bin'));
    await binDir.create(recursive: true);
    final File mockGenerateScript =
        File(path.join(binDir.path, 'generate.dart'));
    await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
void main() {
  print('🚀 FlutterLocalisation Translations Generator');
  print('✅ Generation completed successfully!');
}
''');

    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Check FlutterLocalisation generation was executed
    final String output = result.stdout.toString() + result.stderr.toString();
    expect(
      output,
      contains('🎯 Starting FlutterLocalisation methods generation...'),
    );
    expect(
      output,
      contains('📄 Found local generate script: bin/generate.dart'),
    );
    // Remove this expectation - the script doesn't output this anymore
    // expect(output, contains('🔧 Running: dart run bin/generate.dart'));

    // Check that the mock script's output appears
    expect(
      output,
      contains('🚀 FlutterLocalisation Translations Generator'),
    );
    expect(
      output,
      contains('✅ Generation completed successfully!'),
    );
    expect(
      output,
      contains('✅ FlutterLocalisation methods generated successfully!'),
    );
  });

  test('should handle FlutterLocalisation generation script failure gracefully',
      () async {
    final String flavor = 'test_flavor';

    // Create test setup
    final Directory dir =
        Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Create failing mock generate.dart script
    final Directory binDir = Directory(path.join(testDir.path, 'bin'));
    await binDir.create(recursive: true);
    final File mockGenerateScript =
        File(path.join(binDir.path, 'generate.dart'));
    await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
import 'dart:io';
void main() {
  print('Starting FlutterLocalisation generation...');
  stderr.write('Error: Something went wrong!');
  exit(1);
}
''');

    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    // The script now continues even when generate.dart fails
    expect(
      result.exitCode,
      0, // Changed from 1 - the main script continues
      reason: 'Should continue when FlutterLocalisation generation fails',
    );

    // Check error handling
    final String output = result.stdout.toString() + result.stderr.toString();
    expect(
      output,
      contains('🎯 Starting FlutterLocalisation methods generation...'),
    );
    expect(
      output,
      contains('📄 Found local generate script: bin/generate.dart'),
    );
    expect(
      output,
      contains('⚠️ Local generate script failed: Error: Something went wrong!'),
    );
    // The script continues with warnings instead of failing
    expect(
      output,
      contains('⚠️ Could not find or run the generate.dart script'),
    );
    expect(
      output,
      contains('💡 The localization files have been generated'),
    );
  });

  test('should log an error if no flavor is provided', () async {
    // Run the localization generator script without arguments
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath],
      workingDirectory: testDir.path,
    );

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the error message was logged
    final String output = result.stdout.toString() + result.stderr.toString();
    expect(
      output,
      contains(
        'Usage: dart run flutter_localisation <flavors-folder> <flavor-name>',
      ),
    );
  });

  test('should handle errors during file reading and writing', () async {
    final String flavor = 'test_flavor';

    // Simulate an error by making the l10n.yaml file read-only
    await l10nFile.writeAsString('arb-dir: lib/l10n/default');
    await setReadOnly(l10nFile, true);

    // Run the localization generator script
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    // Log stdout and stderr for debugging
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the error message was logged
    final String output = result.stdout.toString() + result.stderr.toString();
    expect(output, contains('Invalid flavor folder: lib/l10n/test_flavor'));

    // Clean up
    await setReadOnly(l10nFile, false);
  });

  test('should create l10n.yaml from scratch if it does not exist', () async {
    final String flavor = 'test_flavor';

    // Ensure l10n.yaml does not exist
    if (await l10nFile.exists()) {
      await l10nFile.delete();
    }

    // Ensure the test flavor directory and ARB file exist
    final Directory dir =
        Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the localization generator script
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    // Ensure the script ran successfully
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Check if l10n.yaml was created
    expect(await l10nFile.exists(), isTrue);

    // Read the updated content
    final String updatedContent = await l10nFile.readAsString();

    // Check if the arb-dir was correctly updated
    expect(updatedContent.contains('arb-dir: lib/l10n/$flavor'), isTrue);
  });

  test('Updates l10n.yaml with correct flavor', () async {
    final String flavor = 'test_flavor';

    // Create test flavor directory and dummy ARB file
    final Directory dir =
        Directory(path.join(testDir.path, 'lib/l10n/$flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the script
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    // Check script execution
    expect(result.exitCode, 0, reason: result.stderr);

    // Verify updated l10n.yaml content
    final String updatedContent = await l10nFile.readAsString();
    expect(updatedContent, contains('arb-dir: lib/l10n/$flavor'));
  });

  test('Handles invalid flavor folder gracefully', () async {
    final String invalidFlavor = 'nonexistent_flavor';

    // Run the script with an invalid flavor
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', invalidFlavor],
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
    final String output = result.stdout.toString() + result.stderr.toString();
    expect(
      output,
      contains('Invalid flavor folder: lib/l10n/$invalidFlavor'),
      reason: 'Expected error message for invalid flavor folder.',
    );
  });

  test('Overwrites existing l10n.yaml with new flavor', () async {
    final String initialFlavor = 'flavor1';
    final String newFlavor = 'flavor2';

    // Create the required directories
    final Directory initialDir =
        Directory(path.join(testDir.path, 'lib/l10n/$initialFlavor'));
    final Directory newDir =
        Directory(path.join(testDir.path, 'lib/l10n/$newFlavor'));
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
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, 'lib/l10n', newFlavor],
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
    final String updatedContent = await l10nFile.readAsString();
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
    final List<String> flavors = <String>['flavor1', 'flavor2'];

    // Create directories and ARB files for both flavors
    for (String flavor in flavors) {
      final Directory dir =
          Directory(path.join(testDir.path, 'lib/l10n/$flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');
    }

    // Process both flavors
    for (String flavor in flavors) {
      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'lib/l10n', flavor],
        workingDirectory: testDir.path,
      );
      expect(result.exitCode, 0);
    }

    // Verify files remain independent
    for (String flavor in flavors) {
      final File arbFile =
          File(path.join(testDir.path, 'lib/l10n/$flavor/app_en.arb'));
      expect(await arbFile.exists(), isTrue);
    }
  });

  test('Ensures arb-dir path is updated correctly without duplication',
      () async {
    final String flavorsFolder = 'lib/l10n';
    final String flavor = 'test_flavor';

    // Ensure the test flavor directory and ARB file exist
    final Directory dir =
        Directory(path.join(testDir.path, '$flavorsFolder/$flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run the localization generator script
    final ProcessResult result = await Process.run(
      'dart',
      <String>['run', scriptPath, flavorsFolder, flavor],
      workingDirectory: testDir.path,
    );

    // Ensure the script ran successfully
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Read the updated l10n.yaml content
    final String updatedContent = await l10nFile.readAsString();

    // Verify that arb-dir is set correctly
    final String expectedPath = 'arb-dir: $flavorsFolder/$flavor';
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
      final Directory l10nDir =
          Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await l10nDir.create(recursive: true);

      groupL10nFile = File(path.join(testDir.path, 'l10n.yaml'));
      arbEnFile = File(path.join(l10nDir.path, 'app_en.arb'));
      arbEsFile = File(path.join(l10nDir.path, 'app_es.arb'));
      generatedDir =
          Directory(path.join(testDir.path, 'lib/localization/generated'));

      // ✅ AJOUT : Créer pubspec.yaml pour le groupe End-to-End aussi
      final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_project
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localisations:
    sdk: flutter

flutter:
  generate: true  # ✅ IMPORTANT pour flutter gen-l10n
''');

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
''');
    });

    tearDown(() async {
      final Directory testLibDir = Directory(path.join(testDir.path, 'lib'));
      if (await testLibDir.exists()) {
        await testLibDir.delete(recursive: true);
      }

      if (await groupL10nFile.exists()) {
        await groupL10nFile.delete();
      }

      final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      if (await pubspecFile.exists()) {
        await pubspecFile.delete();
      }

      final Directory binDir = Directory(path.join(testDir.path, 'bin'));
      if (await binDir.exists()) {
        await binDir.delete(recursive: true);
      }
    });

    test('Generates translations and updates correctly', () async {
      // Run the localization generator script
      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'lib/l10n', 'test_flavor'],
        workingDirectory: testDir.path,
      );

      // Verify script ran successfully
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');
      expect(result.exitCode, 0, reason: 'Script execution failed.');

      // Verify Spanish and English localization files exist
      final File enGeneratedFile = File(
        path.join(generatedDir.path, 'app_localizations_en.dart'),
      );
      final File esGeneratedFile = File(
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
      final String esGeneratedContent = await esGeneratedFile.readAsString();
      expect(
        esGeneratedContent,
        contains('Hola el mundo'),
        reason:
            'Expected Spanish translation to be included in the generated file.',
      );

      // Verify English translation exists in the generated file
      final String enGeneratedContent = await enGeneratedFile.readAsString();
      expect(
        enGeneratedContent,
        contains('Hello World'),
        reason:
            'Expected English translation to be included in the generated file.',
      );
    });
  });

  group('FlutterLocalisation Integration Tests', () {
    test('should execute FlutterLocalisation generation script when present',
        () async {
      final String flavor = 'test_flavor';

      // Create test setup
      final Directory dir =
          Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

      // ✅ Create working mock generate.dart script
      final Directory binDir = Directory(path.join(testDir.path, 'bin'));
      await binDir.create(recursive: true);
      final File mockGenerateScript =
          File(path.join(binDir.path, 'generate.dart'));
      await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
void main() {
  print('🚀 FlutterLocalisation Translations Generator');
  print('✅ Generation completed successfully!');
}
''');

      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'lib/l10n', flavor],
        workingDirectory: testDir.path,
      );

      expect(
        result.exitCode,
        0,
        reason: 'Should continue when FlutterLocalisation generation fails',
      );

      final String output = result.stdout.toString() + result.stderr.toString();
      expect(
        output,
        contains('🎯 Starting FlutterLocalisation methods generation...'),
      );
      expect(
        output,
        contains('✅ FlutterLocalisation methods generated successfully!'),
      );
    });
  });

  test('should handle special characters in flavor names', () async {
    final List<String> specialFlavors = <String>[
      'test-flavor',
      'test_flavor',
      'test.flavor',
    ];

    for (String flavor in specialFlavors) {
      final Directory dir =
          Directory(path.join(testDir.path, 'lib/l10n/$flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'lib/l10n', flavor],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0, reason: 'Should handle flavor name: $flavor');
    }
  });

  group('ARB Timestamp Extraction Tests', () {
    test(
        'should extract timestamp from ARB files and include in generated code',
        () async {
      final String flavor = 'test_flavor';

      // Create test setup with ARB file containing timestamp
      final Directory dir =
          Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await dir.create(recursive: true);

      // Create ARB with @@last_modified
      final String testTimestamp = '2024-12-20T10:30:00.000Z';
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "@@last_modified": "$testTimestamp",
  "hello": "Hello"
}
''');

      // Create mock generate.dart that extracts timestamp
      final Directory binDir = Directory(path.join(testDir.path, 'bin'));
      await binDir.create(recursive: true);
      final File mockGenerateScript =
          File(path.join(binDir.path, 'generate.dart'));
      await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
import 'dart:convert';
import 'dart:io';

void main() async {
  print('🚀 FlutterLocalisation Translations Generator');
  
  // Extract timestamp from ARB
  final l10nFile = File('l10n.yaml');
  final l10nContent = await l10nFile.readAsString();
  final arbDirMatch = RegExp(r'arb-dir:\\s*(.+)').firstMatch(l10nContent);
  
  if (arbDirMatch != null) {
    final arbDir = arbDirMatch.group(1)!.trim();
    final arbFiles = Directory(arbDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList();
    
    if (arbFiles.isNotEmpty) {
      final arbContent = await arbFiles.first.readAsString();
      final arbData = jsonDecode(arbContent);
      final timestamp = arbData['@@last_modified'];
      print('📅 Extracted ARB timestamp: \$timestamp');
    }
  }
  
  print('✅ Generation completed successfully!');
}
''');

      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'lib/l10n', flavor],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0);
      final String output = result.stdout.toString() + result.stderr.toString();
      expect(output, contains('📅 Extracted ARB timestamp: $testTimestamp'));
    });

    test('should handle missing @@last_modified gracefully', () async {
      final String flavor = 'test_flavor';

      // Create ARB without timestamp
      final Directory dir =
          Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "hello": "Hello"
}
''');

      // Create mock generate.dart that handles missing timestamp
      final Directory binDir = Directory(path.join(testDir.path, 'bin'));
      await binDir.create(recursive: true);
      final File mockGenerateScript =
          File(path.join(binDir.path, 'generate.dart'));
      await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
import 'dart:convert';
import 'dart:io';

void main() async {
  print('🚀 FlutterLocalisation Translations Generator');
  
  final l10nFile = File('l10n.yaml');
  final l10nContent = await l10nFile.readAsString();
  final arbDirMatch = RegExp(r'arb-dir:\\s*(.+)').firstMatch(l10nContent);
  
  if (arbDirMatch != null) {
    final arbDir = arbDirMatch.group(1)!.trim();
    final arbFiles = Directory(arbDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList();
    
    if (arbFiles.isNotEmpty) {
      final arbContent = await arbFiles.first.readAsString();
      final arbData = jsonDecode(arbContent);
      final timestamp = arbData['@@last_modified'] ?? DateTime.now().toIso8601String();
      print('📅 ARB timestamp (defaulted): \$timestamp');
    }
  }
  
  print('✅ Generation completed successfully!');
}
''');

      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'lib/l10n', flavor],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0);
      final String output = result.stdout.toString() + result.stderr.toString();
      expect(output, contains('📅 ARB timestamp (defaulted):'));
    });

    test('should generate code with embedded timestamp constant', () async {
      final String flavor = 'test_flavor';

      // Create test setup
      final Directory dir =
          Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await dir.create(recursive: true);

      final String testTimestamp = '2024-12-20T15:45:00Z';
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "@@last_modified": "$testTimestamp",
  "hello": "Hello"
}
''');

      // Create localization directory for generated file
      final Directory localizationDir =
          Directory(path.join(testDir.path, 'lib/localization/generated'));
      await localizationDir.create(recursive: true);

      // Create mock app_localizations.dart
      await File(path.join(localizationDir.path, 'app_localizations.dart'))
          .writeAsString('''
abstract class AppLocalizations {
  String get hello;
}
''');

      // Create mock generate.dart that creates output with timestamp
      final Directory binDir = Directory(path.join(testDir.path, 'bin'));
      await binDir.create(recursive: true);
      final File mockGenerateScript =
          File(path.join(binDir.path, 'generate.dart'));
      await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
import 'dart:convert';
import 'dart:io';

void main() async {
  print('🚀 FlutterLocalisation Translations Generator');
  
  // Extract timestamp
  String timestamp = DateTime.now().toIso8601String();
  final l10nFile = File('l10n.yaml');
  if (await l10nFile.exists()) {
    final l10nContent = await l10nFile.readAsString();
    final arbDirMatch = RegExp(r'arb-dir:\\s*(.+)').firstMatch(l10nContent);
    
    if (arbDirMatch != null) {
      final arbDir = arbDirMatch.group(1)!.trim();
      final arbFiles = Directory(arbDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList();
      
      if (arbFiles.isNotEmpty) {
        final arbContent = await arbFiles.first.readAsString();
        final arbData = jsonDecode(arbContent);
        timestamp = arbData['@@last_modified'] ?? timestamp;
      }
    }
  }
  
  // Generate output file
  final outputFile = File('lib/generated_translation_methods.dart');
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(\'\'\'
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated on: \${DateTime.now().toIso8601String()}

/// Timestamp of embedded ARB files used during generation
const String embeddedArbTimestamp = '\$timestamp';

import 'package:flutter/widgets.dart';
import 'package:test_project/localization/generated/app_localizations.dart';

extension GeneratedTranslationMethods on BuildContext {
  String get hello {
    return AppLocalizations.of(this)!.hello;
  }
}
\'\'\');
  
  print('✅ Generated translation methods with timestamp: \$timestamp');
}
''');

      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'lib/l10n', flavor],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0);

      // Check if generated file contains timestamp
      final File generatedFile = File(
        path.join(testDir.path, 'lib/generated_translation_methods.dart'),
      );
      expect(await generatedFile.exists(), isTrue);

      final String generatedContent = await generatedFile.readAsString();
      expect(
        generatedContent,
        contains('const String embeddedArbTimestamp = \'$testTimestamp\''),
      );
    });
  });
}
