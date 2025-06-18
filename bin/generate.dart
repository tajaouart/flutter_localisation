#!/usr/bin/env dart
// bin/generate.dart

import 'dart:io';

void main(List<String> args) async {
  print('🚀 FlutterLocalisation Translations Generator');

  try {
    final generator = FlutterTranslationGenerator();
    await generator.generate();
    print('✅ Generation completed successfully!');
  } catch (error) {
    print('❌ Error: $error');
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

    print('📁 Project: $_projectRoot');
    print('📄 Input: $_localizationsPath');
    print('📝 Output: $_outputPath');

    final content = await _readLocalizationsFile();
    final methods = _extractMethods(content);

    if (methods.isEmpty) {
      throw Exception(
          'No translation methods found in generated localizations');
    }

    final generatedCode = _generateCode(methods);
    await _writeGeneratedFile(generatedCode);

    print('✅ Generated ${methods.length} translation methods:');
    for (final method in methods) {
      print('   ✓ ${method.name}${method.isGetter ? ' (getter)' : ''}');
    }
  }

  void _findProjectRoot() {
    Directory current = Directory.current;

    while (current.path != current.parent.path) {
      final pubspecFile = File('${current.path}/pubspec.yaml');
      if (pubspecFile.existsSync()) {
        _projectRoot = current.path;
        return;
      }
      current = current.parent;
    }

    throw Exception(
        'Could not find pubspec.yaml. Please run from within a Flutter project.');
  }

  void _detectPaths() {
    // Auto-detect generated localizations path
    final commonPaths = [
      'lib/localization/generated/app_localizations.dart',
      'lib/generated/intl/app_localizations.dart',
      'lib/l10n/app_localizations.dart',
      'lib/app_localizations.dart',
    ];

    for (final path in commonPaths) {
      final fullPath = '$_projectRoot/$path';
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
    final isDependency = Directory('$_projectRoot/lib/src').existsSync();
    _outputPath = isDependency
        ? '$_projectRoot/lib/src/generated_methods.dart'
        : '$_projectRoot/lib/generated_translation_methods.dart';
  }

  Future<String> _readLocalizationsFile() async {
    final file = File(_localizationsPath);
    return await file.readAsString();
  }

  List<TranslationMethod> _extractMethods(String content) {
    final methods = <TranslationMethod>[];

    // Find abstract class
    final classStart = content.indexOf('abstract class AppLocalizations');
    if (classStart == -1) {
      throw Exception('Could not find abstract class AppLocalizations');
    }

    // Find class end using brace counting
    int classEnd = classStart;
    int braceLevel = 0;
    bool foundOpenBrace = false;

    for (int i = classStart; i < content.length; i++) {
      final char = content[i];
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

    final classContent = content.substring(classStart, classEnd);
    final lines = classContent.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();

      if ((trimmed.startsWith('String ') ||
              trimmed.startsWith('String get ')) &&
          trimmed.endsWith(';') &&
          !trimmed.contains('static')) {
        final method = _parseMethod(trimmed);
        if (method != null &&
            method.name != 'of' &&
            method.name != 'localeName') {
          methods.add(method);
        }
      }
    }

    return methods;
  }

  TranslationMethod? _parseMethod(String line) {
    final cleaned = line.replaceAll(';', '').trim();

    if (!cleaned.startsWith('String ')) return null;

    final withoutString = cleaned.substring(7);

    // Handle getters
    if (!withoutString.contains('(')) {
      final name = withoutString.replaceAll('get ', '').trim();
      return TranslationMethod(name: name, parameters: [], isGetter: true);
    }

    // Handle methods
    final parenIndex = withoutString.indexOf('(');
    final methodName = withoutString.substring(0, parenIndex).trim();

    final paramSection = withoutString
        .substring(parenIndex + 1, withoutString.lastIndexOf(')'))
        .trim();

    final parameters = <MethodParameter>[];
    if (paramSection.isNotEmpty) {
      for (final param in paramSection.split(',')) {
        final parts = param.trim().split(' ');
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

  String _generateCode(List<TranslationMethod> methods) {
    final buffer = StringBuffer();

    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by FlutterLocalisation Translations package');
    buffer.writeln('// Generated on: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln(
        "import 'package:flutter_localisation/flutter_localisation.dart';");
    buffer.writeln();
    buffer.writeln(
        '/// Generated extension methods for FlutterLocalisation translations');
    buffer.writeln('extension GeneratedTranslationMethods on Translator {');

    for (final method in methods) {
      buffer.writeln();
      _generateMethod(buffer, method);
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  void _generateMethod(StringBuffer buffer, TranslationMethod method) {
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
      final paramList =
          method.parameters.map((p) => '${p.type} ${p.name}').join(', ');
      final argsList = method.parameters.map((p) => p.name).join(', ');
      final argsMap =
          method.parameters.map((p) => "'${p.name}': ${p.name}").join(', ');

      buffer.writeln('  /// Generated method for ${method.name}');
      buffer.writeln('  String ${method.name}($paramList) {');
      buffer.writeln('    return translate(');
      buffer.writeln("      '${method.name}',");
      buffer.writeln('      {$argsMap},');
      buffer.writeln(
          '      () => generatedLocalizations.${method.name}($argsList),');
      buffer.writeln('    );');
      buffer.writeln('  }');
    }
  }

  Future<void> _writeGeneratedFile(String content) async {
    final outputFile = File(_outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(content);
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
