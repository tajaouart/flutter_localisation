import 'dart:convert';
import 'dart:io';

void main(final List<String> args) async {
  print('🚀 FlutterLocalisation Translations Generator');

  try {
    final FlutterTranslationGenerator generator = FlutterTranslationGenerator();
    await generator.generate();
    print('✅ Generation completed successfully!');
  } on Exception catch (error) {
    print('❌ Error: $error');
    exit(1);
  }
}

class FlutterTranslationGenerator {
  late final String _projectRoot;
  String? _localizationsPath;
  String? _outputPath;
  Map<String, Map<String, dynamic>> _placeholders =
      <String, Map<String, dynamic>>{};

  /// `use-escaping: true` in l10n.yaml: live updates then arrive with ARB
  /// quoting, which the translator has to read the same way gen-l10n does.
  bool _useEscaping = false;

  /// Members of [Translator] itself. An ARB key with one of these names is
  /// shadowed: `context.tr.refresh` calls the member, not the extension.
  static const Set<String> _translatorMembers = <String>{
    'translate',
    'refresh',
    'cacheStatus',
    'context',
    'service',
    'generatedLocalizations',
    'hashCode',
    'runtimeType',
    'toString',
    'noSuchMethod',
  };

  /// Placeholder keys that change how a value is rendered.
  static const Set<String> _formattingKeys = <String>{
    'type',
    'format',
    'isCustomDateFormat',
    'optionalParameters',
  };

  Future<void> generate() async {
    _findProjectRoot();
    _detectPaths();

    print('📁 Project: $_projectRoot');
    print('📄 Input: $_localizationsPath');
    print('📝 Output: $_outputPath');

    // Extract ARB timestamp
    final String? arbTimestamp = await _extractArbTimestamp();
    print('📅 ARB Timestamp: $arbTimestamp');

    final String content = await _readLocalizationsFile();
    final List<TranslationMethod> methods = _extractMethods(content);
    _placeholders = await _readPlaceholderMetadata();
    _useEscaping = await _readUseEscaping();

    if (methods.isEmpty) {
      throw Exception(
        'No translation methods found in generated localizations',
      );
    }

    final String generatedCode = _generateCode(methods, arbTimestamp);
    await _writeGeneratedFile(generatedCode);

    print('✅ Generated ${methods.length} translation methods:');
    for (final TranslationMethod method in methods) {
      print('   ✓ ${method.name}${method.isGetter ? ' (getter)' : ''}');
    }
    for (final TranslationMethod method in methods) {
      if (_translatorMembers.contains(method.name)) {
        print(
          '⚠️ "${method.name}" is also a Translator member, so '
          'context.tr.${method.name} does not reach this key. Rename the key, '
          'or call GeneratedTranslationMethods(context.tr).${method.name}.',
        );
      }
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

    if (_localizationsPath == null) {
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
    final File file = File(_localizationsPath!);
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
    // Declarations can wrap over several lines once the file is formatted,
    // so read statements up to ";" rather than lines.
    final String body = classContent
        .substring(classContent.indexOf('{') + 1)
        .replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '');

    for (final String statement in body.split(';')) {
      final String trimmed = statement.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (trimmed.startsWith('String ') && !trimmed.contains('static')) {
        final TranslationMethod? method = _parseMethod('$trimmed;');
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
        if (param.trim().isEmpty) continue;
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
    buffer.writeln('// ignore_for_file: non_constant_identifier_names');
    buffer.writeln();
    buffer.writeln(
      "import 'package:flutter_localisation/flutter_localisation.dart';",
    );
    buffer.writeln();
    buffer
        .writeln('/// Timestamp of embedded ARB files used during generation');
    buffer.writeln(
      "const String embeddedArbTimestamp = '${arbTimestamp ?? ''}';",
    );
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
      // Use direct property access on dynamic - this works on all platforms
      buffer.writeln(
        '      () => generatedLocalizations.${method.name} as String,',
      );
      if (_useEscaping) buffer.writeln('      useEscaping: true,');
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
        '      () => generatedLocalizations.${method.name}($argsList) as String,',
      );
      final Map<String, dynamic>? placeholders = _placeholders[method.name];
      if (placeholders != null && placeholders.isNotEmpty) {
        buffer.writeln('      placeholders: ${_dartLiteral(placeholders)},');
      }
      if (_useEscaping) buffer.writeln('      useEscaping: true,');
      buffer.writeln('    );');
      buffer.writeln('  }');
    }
  }

  /// The `placeholders` metadata of each message in the template ARB, kept
  /// to the keys that affect formatting. Live updates carry only the message
  /// text, so the generated methods hand this to the translator.
  Future<Map<String, Map<String, dynamic>>> _readPlaceholderMetadata() async {
    final Map<String, Map<String, dynamic>> result =
        <String, Map<String, dynamic>>{};
    try {
      final File l10nFile = File('$_projectRoot/l10n.yaml');
      if (!l10nFile.existsSync()) return result;
      final String l10n = await l10nFile.readAsString();
      final String arbDir =
          RegExp(r'arb-dir:\s*(.+)').firstMatch(l10n)?.group(1)?.trim() ??
              'lib/l10n';
      final String template = RegExp(r'template-arb-file:\s*(.+)')
              .firstMatch(l10n)
              ?.group(1)
              ?.trim() ??
          'app_en.arb';
      final File arbFile = File('$_projectRoot/$arbDir/$template');
      if (!arbFile.existsSync()) return result;

      final Object? arb = jsonDecode(await arbFile.readAsString());
      if (arb is! Map<String, dynamic>) return result;
      for (final MapEntry<String, dynamic> entry in arb.entries) {
        if (!entry.key.startsWith('@') || entry.key.startsWith('@@')) continue;
        final Object? meta = entry.value;
        if (meta is! Map<String, dynamic>) continue;
        final Object? placeholders = meta['placeholders'];
        if (placeholders is! Map<String, dynamic>) continue;

        final Map<String, dynamic> kept = <String, dynamic>{};
        for (final MapEntry<String, dynamic> placeholder
            in placeholders.entries) {
          final Object? fields = placeholder.value;
          if (fields is! Map<String, dynamic>) continue;
          final Map<String, dynamic> formatting = <String, dynamic>{
            for (final MapEntry<String, dynamic> field in fields.entries)
              if (_formattingKeys.contains(field.key) && field.value != null)
                field.key: field.value,
          };
          if (formatting.isNotEmpty) kept[placeholder.key] = formatting;
        }
        if (kept.isNotEmpty) result[entry.key.substring(1)] = kept;
      }
    } on Exception catch (e) {
      print('Warning: Could not read placeholder metadata: $e');
    }
    return result;
  }

  String _dartLiteral(final Object? value, {final bool isConst = true}) {
    if (value is Map) {
      final String entries = value.entries
          .map(
            (final MapEntry<dynamic, dynamic> e) =>
                '${_dartLiteral(e.key.toString())}: '
                '${_dartLiteral(e.value, isConst: false)}',
          )
          .join(', ');
      return "${isConst ? 'const ' : ''}<String, dynamic>{$entries}";
    }
    if (value is String) {
      final String escaped = value
          .replaceAll(r'\', r'\\')
          .replaceAll("'", r"\'")
          .replaceAll(r'$', r'\$')
          .replaceAll('\n', r'\n');
      return "'$escaped'";
    }
    return '$value';
  }

  Future<bool> _readUseEscaping() async {
    final File l10nFile = File('$_projectRoot/l10n.yaml');
    if (!l10nFile.existsSync()) return false;
    final RegExpMatch? match =
        RegExp(r'^use-escaping:\s*(\w+)', multiLine: true)
            .firstMatch(await l10nFile.readAsString());
    return match?.group(1) == 'true';
  }

  Future<void> _writeGeneratedFile(final String content) async {
    final File outputFile = File(_outputPath!);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(content);
    // Formatted, so a project that checks `dart format` stays green. A missing
    // `dart` on PATH only leaves the file unformatted.
    try {
      await Process.run('dart', <String>['format', outputFile.path]);
    } on ProcessException catch (_) {}
  }

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
      print('Warning: Could not extract ARB timestamp: $e');
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
