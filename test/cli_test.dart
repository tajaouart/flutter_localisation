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
  });
}
