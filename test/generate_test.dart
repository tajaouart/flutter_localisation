import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('FlutterTranslationGenerator Tests', () {
    late Directory tempDir;
    late Directory projectDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('generate_test_');
      projectDir = Directory(path.join(tempDir.path, 'test_project'));
      await projectDir.create();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Method Parsing Tests', () {
      test('should parse simple getter', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  String get hello;
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        expect(await outputFile.exists(), isTrue);

        final String content = await outputFile.readAsString();
        expect(content, contains('String get hello'));
        expect(content, contains("return translate("));
        expect(content, contains("'hello',"));
        expect(content, contains('generatedLocalizations.hello'));
      });

      test('should parse method with single parameter', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  String greet(String name);
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains('String greet(String name)'));
        expect(content, contains("'name': name"));
        expect(content, contains('generatedLocalizations.greet(name)'));
      });

      test('should parse method with multiple parameters', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  String welcome(String name, int count);
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains('String welcome(String name, int count)'));
        expect(content, contains("'name': name"));
        expect(content, contains("'count': count"));
        expect(content, contains('generatedLocalizations.welcome(name, count)'));
      });

      test('should skip static methods', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  String get hello;
  static String of(BuildContext context);
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains('String get hello'));
        expect(content, isNot(contains('static String of')));
      });

      test('should skip localeName property', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  String get localeName;
  String get hello;
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains('String get hello'));
        expect(content, isNot(contains('String get localeName')));
      });

      test('should handle multiple methods and getters', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  String get appTitle;
  String get cancel;
  String greet(String name);
  String itemCount(int count);
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains('String get appTitle'));
        expect(content, contains('String get cancel'));
        expect(content, contains('String greet(String name)'));
        expect(content, contains('String itemCount(int count)'));
      });
    });

    group('ARB Timestamp Extraction Tests', () {
      test('should extract timestamp from ARB file', () async {
        // ARRANGE
        final String timestamp = '2024-12-20T10:30:00.000Z';
        await _setupProject(
          projectDir,
          arbContent: '''
{
  "@@locale": "en",
  "@@last_modified": "$timestamp",
  "hello": "Hello"
}
''',
        );

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains("const String embeddedArbTimestamp = '$timestamp'"));
      });

      test('should handle missing timestamp gracefully', () async {
        // ARRANGE
        await _setupProject(
          projectDir,
          arbContent: '''
{
  "@@locale": "en",
  "hello": "Hello"
}
''',
        );

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains("const String embeddedArbTimestamp = ''"));
      });

      test('should handle invalid ARB JSON gracefully', () async {
        // ARRANGE
        await _setupProject(
          projectDir,
          arbContent: 'invalid json {{{',
        );

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        expect(result.stdout.toString(), contains('Warning: Could not extract ARB timestamp'));
      });
    });

    group('Path Detection Tests', () {
      test('should detect localization in lib/localization/generated/', () async {
        // ARRANGE
        await _setupProjectCustomPath(
          projectDir,
          localizationPath: 'lib/localization/generated/app_localizations.dart',
        );

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        expect(result.stdout.toString(), contains('lib/localization/generated'));
      });

      test('should detect localization in lib/l10n/', () async {
        // ARRANGE
        await _setupProjectCustomPath(
          projectDir,
          localizationPath: 'lib/l10n/app_localizations.dart',
        );

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        expect(result.stdout.toString(), contains('lib/l10n'));
      });

      test('should output to lib/ for apps', () async {
        // ARRANGE - No lib/src directory = app
        await _setupProject(projectDir);

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        expect(await outputFile.exists(), isTrue);
      });

      test('should output to lib/src/ for packages', () async {
        // ARRANGE - Has lib/src directory = package
        await _setupProject(projectDir);
        final Directory srcDir = Directory(path.join(projectDir.path, 'lib', 'src'));
        await srcDir.create(recursive: true);

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'src', 'generated_methods.dart'));
        expect(await outputFile.exists(), isTrue);
      });
    });

    group('Error Handling Tests', () {
      test('should fail if no pubspec.yaml found', () async {
        // ARRANGE - No pubspec.yaml
        final Directory emptyDir = Directory(path.join(tempDir.path, 'empty'));
        await emptyDir.create();

        // ACT
        final ProcessResult result = await _runGenerator(emptyDir);

        // ASSERT
        expect(result.exitCode, 1);
        expect(result.stdout.toString(), contains('Could not find pubspec.yaml'));
      });

      test('should fail if no localization file found', () async {
        // ARRANGE - Only pubspec, no localization file
        await File(path.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: test_project
environment:
  sdk: '>=3.0.0 <4.0.0'
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, isNot(0));
        final String output = result.stdout.toString() + result.stderr.toString();
        expect(output, contains('Could not find generated app_localizations.dart'));
      });

      test('should fail if no methods found in localization file', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  // Empty class
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 1);
        expect(result.stdout.toString(), contains('No translation methods found'));
      });
    });

    group('Generated Code Quality Tests', () {
      test('should generate well-formatted Dart code', () async {
        // ARRANGE
        await _setupProject(projectDir, localizationContent: '''
abstract class AppLocalizations {
  String get hello;
  String greet(String name);
}
''');

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        // Verify basic Dart syntax elements are present
        expect(content, contains('import '));
        expect(content, contains('extension '));
        expect(content, contains('String get hello'));
        expect(content, contains('String greet(String name)'));
        expect(content, isNot(contains('undefined')));
        expect(content, isNot(contains('null')));
      });

      test('should include generation timestamp', () async {
        // ARRANGE
        await _setupProject(projectDir);

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains('// GENERATED CODE - DO NOT MODIFY BY HAND'));
        expect(content, contains('// Generated by FlutterLocalisation'));
        expect(content, contains('// Generated on:'));
      });

      test('should include proper imports', () async {
        // ARRANGE
        await _setupProject(projectDir);

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(
          content,
          contains("import 'package:flutter_localisation/flutter_localisation.dart';"),
        );
      });

      test('should generate extension on Translator', () async {
        // ARRANGE
        await _setupProject(projectDir);

        // ACT
        final ProcessResult result = await _runGenerator(projectDir);

        // ASSERT
        expect(result.exitCode, 0);
        final File outputFile =
            File(path.join(projectDir.path, 'lib', 'generated_translation_methods.dart'));
        final String content = await outputFile.readAsString();

        expect(content, contains('extension GeneratedTranslationMethods on Translator'));
      });
    });
  });
}

// Helper functions

Future<void> _setupProject(
  final Directory projectDir, {
  final String localizationContent = '''
abstract class AppLocalizations {
  String get hello;
}
''',
  final String? arbContent,
}) async {
  // Create pubspec.yaml
  await File(path.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: test_project
environment:
  sdk: '>=3.0.0 <4.0.0'
''');

  // Create lib directory structure
  final Directory libDir = Directory(path.join(projectDir.path, 'lib'));
  final Directory localizationDir =
      Directory(path.join(libDir.path, 'localization', 'generated'));
  await localizationDir.create(recursive: true);

  // Create app_localizations.dart
  await File(path.join(localizationDir.path, 'app_localizations.dart'))
      .writeAsString(localizationContent);

  // Create l10n.yaml and ARB files if arbContent provided
  if (arbContent != null) {
    final Directory arbDir = Directory(path.join(projectDir.path, 'lib', 'l10n'));
    await arbDir.create(recursive: true);

    await File(path.join(projectDir.path, 'l10n.yaml')).writeAsString('''
arb-dir: lib/l10n
output-dir: lib/localization/generated
output-localization-file: app_localizations.dart
''');

    await File(path.join(arbDir.path, 'app_en.arb')).writeAsString(arbContent);
  }
}

Future<void> _setupProjectCustomPath(
  final Directory projectDir, {
  required final String localizationPath,
}) async {
  // Create pubspec.yaml
  await File(path.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: test_project
environment:
  sdk: '>=3.0.0 <4.0.0'
''');

  // Create localization file at custom path
  final File localizationFile = File(path.join(projectDir.path, localizationPath));
  await localizationFile.parent.create(recursive: true);
  await localizationFile.writeAsString('''
abstract class AppLocalizations {
  String get hello;
}
''');
}

Future<ProcessResult> _runGenerator(final Directory projectDir) async {
  final String scriptPath =
      path.join(Directory.current.path, 'bin', 'generate.dart');

  return await Process.run(
    'dart',
    <String>[scriptPath],
    workingDirectory: projectDir.path,
  );
}
