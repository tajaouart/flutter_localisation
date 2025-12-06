import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('FlutterLocalisation CLI Test on Example Project', () {
    // Get the absolute path to the root of your main project
    final String projectRoot = Directory.current.path;
    // Define the path to the 'example' directory
    final Directory exampleDir = Directory(path.join(projectRoot, 'example'));
    // Define the path to the script we are testing
    final String scriptPath =
        path.join(projectRoot, 'bin', 'flutter_localisation.dart');

    // Define the locations of the files that will be generated
    final File generatedL10nFile = File(
      path.join(
        exampleDir.path,
        'lib',
        'localization',
        'generated',
        'app_localizations.dart',
      ),
    );
    final File generatedMethodsFile = File(
      path.join(
        exampleDir.path,
        'lib',
        'generated_translation_methods.dart',
      ),
    );

    test(
      'should successfully run the generation command on the example project',
      () async {
        // (Optional but recommended) Clean up old files before the test runs
        // to ensure we are testing a fresh generation.
        if (await generatedL10nFile.exists()) {
          await generatedL10nFile.parent.delete(recursive: true);
        }
        if (await generatedMethodsFile.exists()) {
          await generatedMethodsFile.delete();
        }

        // ACT: Run the script from within the 'example' directory
        final ProcessResult result = await Process.run(
          'dart',
          <String>['run', scriptPath, 'arbs', 'usa'],
          workingDirectory: exampleDir.path,
        );

        // ASSERT: Verify the results

        // 1. Check that the script exited successfully
        expect(
          result.exitCode,
          0,
          reason: 'Script failed with stderr: ${result.stderr}',
        );

        // 2. Verify that both expected output files were created
        expect(
          await generatedL10nFile.exists(),
          isTrue,
          reason: 'app_localizations.dart was not generated.',
        );
        expect(
          await generatedMethodsFile.exists(),
          isTrue,
          reason: 'generated_translation_methods.dart was not generated.',
        );

        // 3. Verify the content of the generated methods file
        final String methodsFileContent =
            await generatedMethodsFile.readAsString();
        expect(
          methodsFileContent,
          contains('extension GeneratedTranslationMethods on Translator'),
        );
        expect(methodsFileContent, contains('String get appTitle'));
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test('should log that it skips git pull when arbs folder is not a git repo',
        () async {
      // ACT: Run the script on the example project (which doesn't have git in arbs)
      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', scriptPath, 'arbs', 'usa'],
        workingDirectory: exampleDir.path,
      );

      // ASSERT: Check that the output mentions skipping git pull
      final String output = result.stdout.toString();
      expect(
        output,
        contains('is not a Git repository. Skipping git pull'),
        reason: 'Should log that git pull is skipped for non-git folders',
      );
      expect(result.exitCode, 0);
    });

    test(
      'should attempt git pull when arbs folder is a git repo',
      () async {
        // ARRANGE: Create a temporary git repo for testing
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'flutter_localisation_test_',
        );
        final Directory arbsDir = Directory(path.join(tempDir.path, 'arbs'));
        await arbsDir.create();

        // Initialize git repo in arbs folder
        await Process.run(
          'git',
          <String>['init'],
          workingDirectory: arbsDir.path,
        );
        await Process.run(
          'git',
          <String>['config', 'user.email', 'test@example.com'],
          workingDirectory: arbsDir.path,
        );
        await Process.run(
          'git',
          <String>['config', 'user.name', 'Test User'],
          workingDirectory: arbsDir.path,
        );

        // Create a flavor directory with a dummy ARB file
        final Directory flavorDir = Directory(path.join(arbsDir.path, 'test'));
        await flavorDir.create();
        final File arbFile = File(path.join(flavorDir.path, 'app_en.arb'));
        await arbFile.writeAsString('{"@@locale": "en", "test": "Test"}');

        // Commit the ARB file
        await Process.run(
          'git',
          <String>['add', '.'],
          workingDirectory: arbsDir.path,
        );
        await Process.run(
          'git',
          <String>['commit', '-m', 'Initial commit'],
          workingDirectory: arbsDir.path,
        );

        // ACT: Run the CLI tool
        final ProcessResult result = await Process.run(
          'dart',
          <String>['run', scriptPath, 'arbs', 'test'],
          workingDirectory: tempDir.path,
        );

        // ASSERT: Check that git pull was attempted
        final String output = result.stdout.toString();
        expect(
          output,
          contains('Pulling latest changes from Git'),
          reason: 'Should attempt git pull when arbs folder is a git repo',
        );
        // Git pull will fail due to no tracking branch, but should continue gracefully
        expect(
          output,
          contains('Continuing with current ARB files'),
          reason: 'Should continue after git pull failure',
        );

        // Clean up
        await tempDir.delete(recursive: true);
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'should report generated files count on successful generation',
      () async {
        // ACT: Run the script
        final ProcessResult result = await Process.run(
          'dart',
          <String>['run', scriptPath, 'arbs', 'usa'],
          workingDirectory: exampleDir.path,
        );

        // ASSERT: Check output contains file count
        final String output = result.stdout.toString();
        expect(
          output,
          contains('Localization generation completed successfully'),
          reason: 'Should report successful generation',
        );
        expect(
          output,
          contains('Generated'),
          reason: 'Should report number of generated files',
        );
        expect(result.exitCode, 0);
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  });

  group('FlutterLocalisation CLI Error Handling', () {
    final String projectRoot = Directory.current.path;
    final String scriptPath =
        path.join(projectRoot, 'bin', 'flutter_localisation.dart');

    test(
      'should fail with exit code 1 when flavor folder does not exist',
      () async {
        // ARRANGE: Create temp directory without the flavor folder
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'flutter_localisation_test_',
        );
        final Directory arbsDir = Directory(path.join(tempDir.path, 'arbs'));
        await arbsDir.create();
        // Note: NOT creating the 'nonexistent' flavor folder

        // ACT: Run the script with a non-existent flavor
        final ProcessResult result = await Process.run(
          'dart',
          <String>['run', scriptPath, 'arbs', 'nonexistent'],
          workingDirectory: tempDir.path,
        );

        // ASSERT: Should fail with exit code 1
        expect(result.exitCode, 1);
        expect(
          result.stdout.toString(),
          contains('Invalid flavor folder'),
          reason: 'Should report invalid flavor folder',
        );

        // Clean up
        await tempDir.delete(recursive: true);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'should fail with exit code 1 when no ARB files found',
      () async {
        // ARRANGE: Create temp directory with empty flavor folder
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'flutter_localisation_test_',
        );
        final Directory arbsDir = Directory(path.join(tempDir.path, 'arbs'));
        await arbsDir.create();
        final Directory flavorDir =
            Directory(path.join(arbsDir.path, 'empty_flavor'));
        await flavorDir.create();
        // Note: NOT creating any ARB files

        // ACT: Run the script
        final ProcessResult result = await Process.run(
          'dart',
          <String>['run', scriptPath, 'arbs', 'empty_flavor'],
          workingDirectory: tempDir.path,
        );

        // ASSERT: Should fail with exit code 1
        expect(result.exitCode, 1);
        expect(
          result.stdout.toString(),
          contains('No ARB files found'),
          reason: 'Should report no ARB files found',
        );

        // Clean up
        await tempDir.delete(recursive: true);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'should fail with exit code 1 when less than 2 arguments provided',
      () async {
        // ARRANGE: Create temp directory
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'flutter_localisation_test_',
        );

        // ACT: Run the script with only one argument
        final ProcessResult result = await Process.run(
          'dart',
          <String>['run', scriptPath, 'arbs'],
          workingDirectory: tempDir.path,
        );

        // ASSERT: Should fail with exit code 1
        expect(result.exitCode, 1);
        expect(
          result.stdout.toString(),
          contains('Both arguments are required'),
          reason: 'Should report that both arguments are required',
        );

        // Clean up
        await tempDir.delete(recursive: true);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'should fail with exit code 1 when no arguments provided',
      () async {
        // ARRANGE: Create temp directory
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'flutter_localisation_test_',
        );

        // ACT: Run the script with no arguments
        final ProcessResult result = await Process.run(
          'dart',
          <String>['run', scriptPath],
          workingDirectory: tempDir.path,
        );

        // ASSERT: Should fail with exit code 1
        expect(result.exitCode, 1);
        expect(
          result.stdout.toString(),
          contains('Both arguments are required'),
          reason: 'Should report that both arguments are required',
        );

        // Clean up
        await tempDir.delete(recursive: true);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
