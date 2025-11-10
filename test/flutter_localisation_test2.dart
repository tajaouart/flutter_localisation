import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('Real-World Global Package Usage', () {
    late Directory testDir;
    late String projectRoot;

    setUpAll(() async {
      projectRoot = Directory.current.path;

      // Verify we're in the right project
      if (!projectRoot.contains('flutter_localisation')) {
        throw Exception('Test must be run from flutter_localisation project');
      }
    });

    setUp(() async {
      // Create a test Flutter project directory
      final Directory tempDir = Directory.systemTemp;
      final int randomId = Random().nextInt(999999);
      testDir = Directory(
        path.join(tempDir.path, 'test_flutter_app_$randomId'),
      );
      await testDir.create(recursive: true);
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('should work as globally activated package', () async {
      // Step 1: Create a realistic Flutter project
      final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: my_app
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
  generate: true
''');

      // Step 2: Create ARB files structure like real projects
      final String arbFolder = 'assets/l10n';
      final String flavor = 'production';

      final Directory arbDir = Directory(
        path.join(testDir.path, arbFolder, flavor),
      );
      await arbDir.create(recursive: true);

      await File(path.join(arbDir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "appTitle": "My Production App",
  "welcomeMessage": "Welcome to our app!"
}
''');

      // Step 3: Run the command as if globally activated
      final ProcessResult result = await Process.run(
        'dart',
        <String>[
          'run',
          path.join(projectRoot, 'bin', 'flutter_localisation.dart'),
          arbFolder,
          flavor,
        ],
        workingDirectory: testDir.path,
      );

      print('Exit code: ${result.exitCode}');
      print('Stdout: ${result.stdout}');
      print('Stderr: ${result.stderr}');

      // Assertions
      expect(result.exitCode, 0, reason: 'Script should exit successfully');

      // Verify l10n.yaml was created/updated
      final File l10nFile = File(path.join(testDir.path, 'l10n.yaml'));
      expect(await l10nFile.exists(), isTrue, reason: 'l10n.yaml should exist');

      final String l10nContent = await l10nFile.readAsString();
      expect(l10nContent, contains('arb-dir: $arbFolder/$flavor'));

      // Verify flutter gen-l10n was called
      final String output = result.stdout.toString();
      expect(
        output,
        contains('Localization generation completed successfully'),
      );

      // Verify generate.dart was found and executed (when package is installed)
      expect(
        output,
        contains('FlutterLocalisation methods generated successfully!'),
      );
    });

    test('should handle multiple sequential flavor switches in CI/CD',
        () async {
      // Create basic Flutter project
      final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: multi_flavor_app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  generate: true
''');

      // Create multiple flavors
      final String arbFolder = 'l10n';
      final List<String> flavors = <String>['dev', 'staging', 'prod'];

      for (String flavor in flavors) {
        final Directory arbDir = Directory(
          path.join(testDir.path, arbFolder, flavor),
        );
        await arbDir.create(recursive: true);

        await File(path.join(arbDir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "environment": "$flavor environment"
}
''');
      }

      // Switch between flavors like in CI/CD
      for (String flavor in flavors) {
        final ProcessResult result = await Process.run(
          'dart',
          <String>[
            'run',
            path.join(projectRoot, 'bin', 'flutter_localisation.dart'),
            arbFolder,
            flavor,
          ],
          workingDirectory: testDir.path,
        );

        expect(
          result.exitCode,
          0,
          reason: 'Should handle flavor $flavor successfully',
        );

        // Verify l10n.yaml is updated for each flavor
        final File l10nFile = File(path.join(testDir.path, 'l10n.yaml'));
        final String content = await l10nFile.readAsString();
        expect(
          content,
          contains('arb-dir: $arbFolder/$flavor'),
          reason: 'l10n.yaml should be updated for $flavor',
        );
      }
    });

    test('should work with widget-chat-arbs structure from production',
        () async {
      // This tests the exact structure from your production logs
      final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: widget_chat_app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  generate: true
''');

      // Create the exact structure from your logs
      final String arbFolder = 'widget-chat-arbs';
      final String flavor = 'Default';

      final Directory arbDir = Directory(
        path.join(testDir.path, arbFolder, flavor),
      );
      await arbDir.create(recursive: true);

      await File(path.join(testDir.path, arbFolder, flavor, 'app_en.arb'))
          .writeAsString('''
{
  "@@locale": "en",
  "chatTitle": "Widget Chat"
}
''');

      final ProcessResult result = await Process.run(
        'dart',
        <String>[
          'run',
          path.join(projectRoot, 'bin', 'flutter_localisation.dart'),
          arbFolder,
          flavor,
        ],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0);

      final File l10nFile = File(path.join(testDir.path, 'l10n.yaml'));
      final String content = await l10nFile.readAsString();
      expect(content, contains('arb-dir: $arbFolder/$flavor'));

      // Should successfully run generate.dart from package
      final String output = result.stdout.toString();
      expect(
        output,
        contains('FlutterLocalisation methods generated successfully'),
      );
    });
  });

  group('Generate.dart Integration', () {
    late Directory testDir;
    late String projectRoot;

    setUp(() async {
      projectRoot = Directory.current.path;

      final Directory tempDir = Directory.systemTemp;
      final int randomId = Random().nextInt(999999);
      testDir = Directory(
        path.join(tempDir.path, 'test_generate_$randomId'),
      );
      await testDir.create(recursive: true);

      // Basic Flutter project
      final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  generate: true
''');
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('should find and run generate.dart from pub cache', () async {
      // Create ARB structure
      final String arbFolder = 'l10n';
      final String flavor = 'test';

      final Directory arbDir = Directory(
        path.join(testDir.path, arbFolder, flavor),
      );
      await arbDir.create(recursive: true);

      await File(path.join(arbDir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "message": "Test message"
}
''');

      // Run the main script
      final ProcessResult result = await Process.run(
        'dart',
        <String>[
          'run',
          path.join(projectRoot, 'bin', 'flutter_localisation.dart'),
          arbFolder,
          flavor,
        ],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0);

      final String output = result.stdout.toString();

      // Should complete main localization
      expect(
        output,
        contains('Localization generation completed successfully'),
      );

      // Should find generate.dart in pub cache (since package is installed)
      expect(
        output,
        anyOf(
          contains('Found generate script in pub cache'),
          contains('Found local generate script'), // During development
        ),
      );

      // Should successfully run generate.dart
      expect(
        output,
        contains('FlutterLocalisation methods generated successfully'),
      );
    });

    test(
        'should prioritize local generate.dart over pub cache during development',
        () async {
      // Create ARB structure
      final String arbFolder = 'l10n';
      final String flavor = 'test';

      final Directory arbDir = Directory(
        path.join(testDir.path, arbFolder, flavor),
      );
      await arbDir.create(recursive: true);

      await File(path.join(arbDir.path, 'app_en.arb')).writeAsString('''
{
  "@@locale": "en",
  "message": "Test message"
}
''');

      // Create a local generate.dart that outputs a custom message
      final Directory binDir = Directory(path.join(testDir.path, 'bin'));
      await binDir.create(recursive: true);

      await File(path.join(binDir.path, 'generate.dart')).writeAsString('''
void main() {
  print('LOCAL generate.dart executed!');
  print('This takes priority over pub cache version');
}
''');

      final ProcessResult result = await Process.run(
        'dart',
        <String>[
          'run',
          path.join(projectRoot, 'bin', 'flutter_localisation.dart'),
          arbFolder,
          flavor,
        ],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, 0);

      final String output = result.stdout.toString();

      // Should use local generate.dart when available
      expect(output, contains('Found local generate script'));
      expect(output, contains('LOCAL generate.dart executed!'));
      expect(output, contains('This takes priority over pub cache version'));
      expect(
        output,
        contains('FlutterLocalisation methods generated successfully!'),
      );
    });
  });

  group('Error Handling', () {
    late Directory testDir;
    late String projectRoot;

    setUp(() async {
      projectRoot = Directory.current.path;

      final Directory tempDir = Directory.systemTemp;
      final int randomId = Random().nextInt(999999);
      testDir = Directory(
        path.join(tempDir.path, 'test_errors_$randomId'),
      );
      await testDir.create(recursive: true);
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('should fail gracefully with invalid flavor folder', () async {
      final File pubspecFile = File(path.join(testDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  generate: true
''');

      // Try to use non-existent flavor
      final ProcessResult result = await Process.run(
        'dart',
        <String>[
          'run',
          path.join(projectRoot, 'bin', 'flutter_localisation.dart'),
          'l10n',
          'non_existent_flavor',
        ],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, isNot(0));

      final String output = result.stdout.toString() + result.stderr.toString();
      expect(
        output,
        contains('Invalid flavor folder: l10n/non_existent_flavor'),
      );
    });

    test('should fail with missing arguments', () async {
      final ProcessResult result = await Process.run(
        'dart',
        <String>[
          'run',
          path.join(projectRoot, 'bin', 'flutter_localisation.dart'),
        ],
        workingDirectory: testDir.path,
      );

      expect(result.exitCode, isNot(0));

      final String output = result.stdout.toString() + result.stderr.toString();
      expect(
        output,
        contains(
          'Usage: dart run flutter_localisation <flavors-folder> <flavor-name>',
        ),
      );
    });
  });
}
