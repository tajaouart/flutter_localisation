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

// ✅ AJOUTEZ cette fonction de sécurité après les imports :
  void _ensureInTestDirectory(String pathToCheck, String testDirPath) {
    if (!pathToCheck.contains('flutter_localisation_test_')) {
      throw Exception(
          '🚨 SÉCURITÉ: Tentative d\'opération sur un chemin non-test: $pathToCheck');
    }
    if (!pathToCheck.contains(testDirPath)) {
      throw Exception(
          '🚨 SÉCURITÉ: Chemin en dehors du dossier de test: $pathToCheck');
    }
  }

// ✅ MODIFIEZ votre setUpAll() - remplacez la partie création testDir :
  setUpAll(() async {
    // Sauvegarder le répertoire du projet
    projectRoot = Directory.current.path;
    scriptPath = path.join(projectRoot, 'bin', 'flutter_localisation.dart');

    // 🛡️ GARDE-FOU: Vérifier qu'on est dans le bon projet
    if (!projectRoot.contains('flutter_localisation')) {
      throw Exception(
          '🚨 SÉCURITÉ: Test lancé depuis un mauvais répertoire: $projectRoot');
    }

    // Vérifier que le script existe
    if (!await File(scriptPath).exists()) {
      throw Exception('Script not found: $scriptPath');
    }

    // 🛡️ GARDE-FOU: Créer un dossier temporaire TRÈS spécifique
    final tempDir = Directory.systemTemp;
    final randomId = Random().nextInt(999999);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    testDir = Directory(path.join(
        tempDir.path, 'SAFE_flutter_localisation_test_${randomId}_$timestamp'));
    await testDir.create(recursive: true);

    // 🛡️ GARDE-FOU: Vérifier qu'on est bien dans un dossier temporaire
    if (!testDir.path.contains(tempDir.path)) {
      throw Exception(
          '🚨 SÉCURITÉ: testDir n\'est pas dans le dossier temporaire!');
    }
    if (testDir.path.contains(projectRoot)) {
      throw Exception('🚨 SÉCURITÉ: testDir est dans le projet! Danger!');
    }

    print('🛡️  SÉCURISÉ: Tests running in: ${testDir.path}');
    print('📄 Script path: $scriptPath');
  });

// ✅ MODIFIEZ votre tearDown() - ajoutez les validations avant chaque delete :
  tearDown(() async {
    // 🛡️ GARDE-FOU: Nettoyer seulement les fichiers de test
    if (await l10nFile.exists()) {
      await _setReadOnly(l10nFile, false);
      await l10nFile.delete();
    }

    // Nettoyer le pubspec.yaml de test
    final pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
    if (await pubspecFile.exists()) {
      await pubspecFile.delete();
    }

    // 🛡️ SÉCURISÉ: Nettoyer les scripts mock avec validation
    final binDir = Directory(path.join(testDir.path, 'bin'));
    if (await binDir.exists()) {
      _ensureInTestDirectory(
          binDir.path, testDir.path); // ← AJOUTEZ cette ligne
      await binDir.delete(recursive: true);
    }

    // 🛡️ SÉCURISÉ: Nettoyer le lib/ avec validation
    final testLibDir = Directory(path.join(testDir.path, 'lib'));
    if (await testLibDir.exists()) {
      _ensureInTestDirectory(
          testLibDir.path, testDir.path); // ← AJOUTEZ cette ligne
      await testLibDir.delete(recursive: true);
    }
  });

// ✅ MODIFIEZ votre tearDownAll() - ajoutez la validation :
  tearDownAll(() async {
    // 🛡️ GARDE-FOU: Double vérification avant suppression
    if (await testDir.exists()) {
      // Vérifier qu'on supprime bien un dossier temporaire
      if (!testDir.path.contains('SAFE_flutter_localisation_test_')) {
        throw Exception(
            '🚨 SÉCURITÉ: Tentative de suppression d\'un dossier non-test!');
      }
      if (testDir.path.contains(projectRoot)) {
        throw Exception(
            '🚨 SÉCURITÉ: Tentative de suppression dans le projet!');
      }

      await testDir.delete(recursive: true);
      print('🧹 SÉCURISÉ: Cleaned up test directory: ${testDir.path}');
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

  // ✅ NOUVEAU: Test du message d'aide mis à jour
  test('should show updated usage message with --with-saas flag', () async {
    // Run the localization generator script without arguments
    final result = await Process.run(
      'dart',
      ['run', scriptPath],
      workingDirectory: testDir.path,
    );

    // Ensure the script exits with an error
    expect(result.exitCode, isNot(0));

    // Check if the updated error message was logged
    final output = result.stdout + result.stderr;
    expect(
        output,
        contains(
            'Usage: dart run flutter_localization <flavors-folder> <flavor-name> [--with-saas]'));
    expect(
        output,
        contains(
            'Add --with-saas to also generate SaaS methods automatically.'));
  });

  // ✅ NOUVEAU: Test que le tip est affiché sans --with-saas
  test('should show tip when --with-saas flag is not provided', () async {
    final flavor = 'test_flavor';

    // Create test setup
    final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run without --with-saas flag
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor],
      workingDirectory: testDir.path,
    );

    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Check that tip is shown
    final output = result.stdout + result.stderr;
    expect(
        output,
        contains(
            '💡 Tip: Add --with-saas to also generate SaaS methods automatically'));
  });

  // ✅ NOUVEAU: Test avec --with-saas flag (pas de script generate.dart)
  test('should handle missing generate.dart script gracefully with --with-saas',
      () async {
    final flavor = 'test_flavor';

    // Create test setup
    final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Run with --with-saas flag (but no generate.dart exists)
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor, '--with-saas'],
      workingDirectory: testDir.path,
    );

    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0,
        reason: 'Should complete successfully even without generate.dart');

    // Check SaaS generation was attempted but skipped
    final output = result.stdout + result.stderr;
    expect(output, contains('🎯 Starting SaaS methods generation...'));
    expect(
        output,
        contains(
            '❌ SaaS generation script not found in any of these locations:'));
    expect(
        output,
        contains(
            '💡 Skipping SaaS method generation. Run "saas_generate" manually if needed.'));
  });

  // ✅ NOUVEAU: Test avec un mock generate.dart script
  test(
      'should run SaaS generation successfully with --with-saas when script exists',
      () async {
    final flavor = 'test_flavor';

    // Create test setup
    final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Create mock generate.dart script in bin/
    final binDir = Directory(path.join(testDir.path, 'bin'));
    await binDir.create(recursive: true);
    final mockGenerateScript = File(path.join(binDir.path, 'generate.dart'));
    await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
void main() {
  print('🚀 SaaS Translations Generator');
  print('✅ Generation completed successfully!');
}
''');

    // Run with --with-saas flag
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor, '--with-saas'],
      workingDirectory: testDir.path,
    );

    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 0, reason: result.stderr);

    // Check SaaS generation was executed
    final output = result.stdout + result.stderr;
    expect(output, contains('🎯 Starting SaaS methods generation...'));
    expect(output, contains('📄 Found SaaS script: bin/generate.dart'));
    expect(output, contains('🔧 Running: dart run bin/generate.dart'));
    expect(output, contains('✅ SaaS methods generated successfully!'));
  });

  // ✅ NOUVEAU: Test gestion d'erreur du script SaaS
  test('should handle SaaS generation script failure gracefully', () async {
    final flavor = 'test_flavor';

    // Create test setup
    final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

    // Create failing mock generate.dart script
    final binDir = Directory(path.join(testDir.path, 'bin'));
    await binDir.create(recursive: true);
    final mockGenerateScript = File(path.join(binDir.path, 'generate.dart'));
    await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
import 'dart:io';
void main() {
  print('Starting SaaS generation...');
  stderr.write('Error: Something went wrong!');
  exit(1);
}
''');

    // Run with --with-saas flag
    final result = await Process.run(
      'dart',
      ['run', scriptPath, 'lib/l10n', flavor, '--with-saas'],
      workingDirectory: testDir.path,
    );

    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    expect(result.exitCode, 1,
        reason: 'Should fail when SaaS generation fails');

    // Check error handling
    final output = result.stdout + result.stderr;
    expect(output, contains('🎯 Starting SaaS methods generation...'));
    expect(output, contains('❌ SaaS generation failed with exit code: 1'));
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
        'Usage: dart run flutter_localization <flavors-folder> <flavor-name> [--with-saas]',
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

      // ✅ AJOUT : Créer pubspec.yaml pour le groupe End-to-End aussi
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

      // Nettoyer le pubspec.yaml du groupe End-to-End
      final pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      if (await pubspecFile.exists()) {
        await pubspecFile.delete();
      }

      // ✅ NOUVEAU: Nettoyer les scripts mock du groupe End-to-End aussi
      final binDir = Directory(path.join(testDir.path, 'bin'));
      if (await binDir.exists()) {
        await binDir.delete(recursive: true);
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

  // ✅ NOUVEAU: Tests spécifiques pour la fonctionnalité SaaS
  group('SaaS Integration Tests', () {
    test('should detect --with-saas flag correctly', () async {
      final flavor = 'test_flavor';

      // Create test setup
      final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

      // ✅ Assurer qu'aucun script mock n'existe
      final binDir = Directory(path.join(testDir.path, 'bin'));
      if (await binDir.exists()) {
        await binDir.delete(recursive: true);
      }

      // Test avec flag --with-saas (sans script = should skip gracefully)
      final result = await Process.run(
        'dart',
        ['run', scriptPath, 'lib/l10n', flavor, '--with-saas'],
        workingDirectory: testDir.path,
      );

      final output = result.stdout + result.stderr;
      expect(output, contains('🎯 Starting SaaS methods generation...'),
          reason: 'Should start SaaS generation when flag is present');

      // Test que la génération SaaS est tentée mais skippée
      expect(output, contains('💡 Skipping SaaS method generation'),
          reason: 'Should skip SaaS generation when script is not found');
    });

    test('should work with working SaaS script', () async {
      final flavor = 'test_flavor';

      // Create test setup
      final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

      // ✅ Create working mock generate.dart script
      final binDir = Directory(path.join(testDir.path, 'bin'));
      await binDir.create(recursive: true);
      final mockGenerateScript = File(path.join(binDir.path, 'generate.dart'));
      await mockGenerateScript.writeAsString('''
#!/usr/bin/env dart
void main() {
  print('🚀 SaaS Translations Generator');
  print('✅ Generation completed successfully!');
}
''');

      // Test with --with-saas flag
      final result = await Process.run(
        'dart',
        ['run', scriptPath, 'lib/l10n', flavor, '--with-saas'],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0,
          reason: 'Should complete successfully with working script');

      final output = result.stdout + result.stderr;
      expect(output, contains('🎯 Starting SaaS methods generation...'));
      expect(output, contains('✅ SaaS methods generated successfully!'));
    });

    test('should ignore unknown flags gracefully', () async {
      final flavor = 'test_flavor';

      // Create test setup
      final dir = Directory(path.join(testDir.path, 'lib/l10n/test_flavor'));
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'app_en.arb')).writeAsString('{}');

      // Test with unknown flag - should still work but not trigger SaaS
      final result = await Process.run(
        'dart',
        ['run', scriptPath, 'lib/l10n', flavor, '--unknown-flag'],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0, reason: 'Should ignore unknown flags');

      final output = result.stdout + result.stderr;
      expect(
          output,
          contains(
              '💡 Tip: Add --with-saas to also generate SaaS methods automatically'),
          reason: 'Should show tip when --with-saas is not present');
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
