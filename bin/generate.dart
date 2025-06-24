import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main(final List<String> args) async {
  debugPrint('🚀 FlutterLocalisation Translations Generator');

  try {
    final FlutterTranslationGenerator generator = FlutterTranslationGenerator();
    await generator.generate();
    debugPrint('✅ Generation completed successfully!');
  } on Exception catch (error) {
    debugPrint('❌ Error: $error');
    exit(1);
  }
}

class FlutterTranslationGenerator {
  late final String _projectRoot;
  late final String _localizationsPath;
  late final String _outputPath;

  Future<void> generate() async {
    _findProjectRoot();
    _detectPaths();

    debugPrint('📁 Project: $_projectRoot');
    debugPrint('📄 Input: $_localizationsPath');
    debugPrint('📝 Output: $_outputPath');

    // Extract ARB timestamp
    final String? arbTimestamp = await _extractArbTimestamp();
    debugPrint('📅 ARB Timestamp: $arbTimestamp');

    final String content = await _readLocalizationsFile();
    final List<TranslationMethod> methods = _extractMethods(content);

    if (methods.isEmpty) {
      throw Exception(
        'No translation methods found in generated localizations',
      );
    }

    final String generatedCode = _generateCode(methods, arbTimestamp);
    await _writeGeneratedFile(generatedCode);

    debugPrint('✅ Generated ${methods.length} translation methods:');
    for (final TranslationMethod method in methods) {
      debugPrint('   ✓ ${method.name}${method.isGetter ? ' (getter)' : ''}');
    }
  }

  void _findProjectRoot() {
    Directory current = Directory.current;

    while (current.path != current.parent.path) {
      final File pubspecFile = File('${current.path}/pubspec.yaml');
      if (pubspecFile.existsSync()) {
        _projectRoot = current.path;
        return;
      }
      current = current.parent;
    }

    throw Exception(
      'Could not find pubspec.yaml. Please run from within a Flutter project.',
    );
  }

  void _detectPaths() {
    // Auto-detect generated localizations path
    final List<String> commonPaths = <String>[
      'lib/localization/generated/app_localizations.dart',
      'lib/generated/intl/app_localizations.dart',
      'lib/l10n/app_localizations.dart',
      'lib/app_localizations.dart',
    ];

    for (final String path in commonPaths) {
      final String fullPath = '$_projectRoot/$path';
      if (File(fullPath).existsSync()) {
        _localizationsPath = fullPath;
        break;
      }
    }

    if (_localizationsPath.isEmpty) {
      throw Exception('Could not find generated app_localizations.dart. '
          'Please run "flutter gen-l10n" first.');
    }

    // Output path in lib/src/ for packages, or root lib/ for apps
    final bool isDependency = Directory('$_projectRoot/lib/src').existsSync();
    _outputPath = isDependency
        ? '$_projectRoot/lib/src/generated_methods.dart'
        : '$_projectRoot/lib/generated_translation_methods.dart';
  }

  Future<String> _readLocalizationsFile() async {
    final File file = File(_localizationsPath);
    return await file.readAsString();
  }

  List<TranslationMethod> _extractMethods(final String content) {
    final List<TranslationMethod> methods = <TranslationMethod>[];

    // Find abstract class
    final int classStart = content.indexOf('abstract class AppLocalizations');
    if (classStart == -1) {
      throw Exception('Could not find abstract class AppLocalizations');
    }

    // Find class end using brace counting
    int classEnd = classStart;
    int braceLevel = 0;
    bool foundOpenBrace = false;

    for (int i = classStart; i < content.length; i++) {
      final String char = content[i];
      if (char == '{') {
        braceLevel++;
        foundOpenBrace = true;
      } else if (char == '}') {
        braceLevel--;
        if (foundOpenBrace && braceLevel == 0) {
          classEnd = i;
          break;
        }
      }
    }

    final String classContent = content.substring(classStart, classEnd);
    final List<String> lines = classContent.split('\n');

    for (final String line in lines) {
      final String trimmed = line.trim();

      if ((trimmed.startsWith('String ') ||
              trimmed.startsWith('String get ')) &&
          trimmed.endsWith(';') &&
          !trimmed.contains('static')) {
        final TranslationMethod? method = _parseMethod(trimmed);
        if (method != null &&
            method.name != 'of' &&
            method.name != 'localeName') {
          methods.add(method);
        }
      }
    }

    return methods;
  }

  TranslationMethod? _parseMethod(final String line) {
    final String cleaned = line.replaceAll(';', '').trim();

    if (!cleaned.startsWith('String ')) return null;

    final String withoutString = cleaned.substring(7);

    // Handle getters
    if (!withoutString.contains('(')) {
      final String name = withoutString.replaceAll('get ', '').trim();
      return TranslationMethod(
        name: name,
        parameters: <MethodParameter>[],
        isGetter: true,
      );
    }

    // Handle methods
    final int parenIndex = withoutString.indexOf('(');
    final String methodName = withoutString.substring(0, parenIndex).trim();

    final String paramSection = withoutString
        .substring(parenIndex + 1, withoutString.lastIndexOf(')'))
        .trim();

    final List<MethodParameter> parameters = <MethodParameter>[];
    if (paramSection.isNotEmpty) {
      for (final String param in paramSection.split(',')) {
        final List<String> parts = param.trim().split(' ');
        if (parts.length >= 2) {
          parameters.add(MethodParameter(type: parts[0], name: parts[1]));
        }
      }
    }

    return TranslationMethod(
      name: methodName,
      parameters: parameters,
      isGetter: false,
    );
  }

  String _generateCode(
    final List<TranslationMethod> methods,
    final String? arbTimestamp,
  ) {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by FlutterLocalisation Translations package');
    buffer.writeln('// Generated on: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln(
      "import 'package:flutter_localisation/flutter_localisation.dart';",
    );
    buffer.writeln();
    buffer
        .writeln('/// Timestamp of embedded ARB files used during generation');
    buffer.writeln("const String embeddedArbTimestamp = '$arbTimestamp';");
    buffer.writeln();

    buffer.writeln(
      '/// Generated extension methods for FlutterLocalisation translations',
    );
    buffer.writeln('extension GeneratedTranslationMethods on Translator {');

    for (final TranslationMethod method in methods) {
      buffer.writeln();
      _generateMethod(buffer, method);
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  void _generateMethod(
    final StringBuffer buffer,
    final TranslationMethod method,
  ) {
    if (method.isGetter) {
      buffer.writeln('  /// Generated getter for ${method.name}');
      buffer.writeln('  String get ${method.name} {');
      buffer.writeln('    return translate(');
      buffer.writeln("      '${method.name}',");
      buffer.writeln('      {},');
      buffer.writeln('      () => generatedLocalizations.${method.name},');
      buffer.writeln('    );');
      buffer.writeln('  }');
    } else {
      final String paramList = method.parameters
          .map((final MethodParameter p) => '${p.type} ${p.name}')
          .join(', ');
      final String argsList =
          method.parameters.map((final MethodParameter p) => p.name).join(', ');
      final String argsMap = method.parameters
          .map((final MethodParameter p) => "'${p.name}': ${p.name}")
          .join(', ');

      buffer.writeln('  /// Generated method for ${method.name}');
      buffer.writeln('  String ${method.name}($paramList) {');
      buffer.writeln('    return translate(');
      buffer.writeln("      '${method.name}',");
      buffer.writeln('      {$argsMap},');
      buffer.writeln(
        '      () => generatedLocalizations.${method.name}($argsList),',
      );
      buffer.writeln('    );');
      buffer.writeln('  }');
    }
  }

  Future<void> _writeGeneratedFile(final String content) async {
    final File outputFile = File(_outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(content);
  }

  /// TODO create test
  Future<String?> _extractArbTimestamp() async {
    try {
      final File l10nFile = File('$_projectRoot/l10n.yaml');
      if (!l10nFile.existsSync()) return null;

      final String l10nContent = await l10nFile.readAsString();
      final RegExpMatch? arbDirMatch =
          RegExp(r'arb-dir:\s*(.+)').firstMatch(l10nContent);
      if (arbDirMatch == null) return null;

      final String arbDir = arbDirMatch.group(1)!.trim();
      final String arbPath = '$_projectRoot/$arbDir';

      final Directory arbDirectory = Directory(arbPath);
      if (!arbDirectory.existsSync()) return null;

      final List<File> arbFiles = arbDirectory
          .listSync()
          .whereType<File>()
          .where((final File file) => file.path.endsWith('.arb'))
          .toList();
      if (arbFiles.isEmpty) return null;

      final String arbContent = await arbFiles.first.readAsString();
      final Map<String, dynamic> arbData = jsonDecode(arbContent);
      final Object? lastModifiedRaw = arbData['@@last_modified'];
      final String? lastModified =
          (lastModifiedRaw is String) ? lastModifiedRaw : null;
      return lastModified;
    } on Exception catch (e) {
      debugPrint('Warning: Could not extract ARB timestamp: $e');
      return null;
    }
  }
}

class TranslationMethod {
  final String name;
  final List<MethodParameter> parameters;
  final bool isGetter;

  TranslationMethod({
    required this.name,
    required this.parameters,
    required this.isGetter,
  });
}

class MethodParameter {
  final String type;
  final String name;

  MethodParameter({required this.type, required this.name});
}
