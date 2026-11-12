import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// The generated `<stem>_<language>.dart` files no ARB asks for any more.
///
/// `flutter gen-l10n` writes one file per language but never deletes one, so
/// a language removed from the project left its old file behind. That file
/// still implements the old `AppLocalizations` and fails `flutter analyze`
/// as soon as a key is added.
List<String> staleLocaleFiles({
  required final Iterable<String> generatedFiles,
  required final String outputFile,
  required final Iterable<String> locales,
}) {
  final String stem = path.basenameWithoutExtension(outputFile);
  final Set<String> languages = locales
      .map((final String l) => l.split(RegExp('[-_]')).first.toLowerCase())
      .toSet();
  final RegExp perLanguage = RegExp(
    '^${RegExp.escape(stem)}_([a-z]{2,3})\\.dart\$',
  );
  final List<String> stale = <String>[];
  for (final String file in generatedFiles) {
    final RegExpMatch? match = perLanguage.firstMatch(path.basename(file));
    if (match != null && !languages.contains(match.group(1))) stale.add(file);
  }
  return stale;
}

/// The locale an ARB is for: its `@@locale`, else what follows the last
/// underscore-separated language code in the file name (`app_es_MX.arb`).
String? arbLocale(final File arb) {
  try {
    final Object? json = jsonDecode(arb.readAsStringSync());
    if (json is Map && json['@@locale'] is String) {
      return json['@@locale'] as String;
    }
  } on FormatException {
    // Fall through to the file name; gen-l10n reports the broken file itself.
  }
  final RegExpMatch? match = RegExp(
    r'_([a-z]{2,3}(?:[-_][A-Za-z0-9]{2,8})*)\.arb$',
  ).firstMatch(path.basename(arb.path));
  return match?.group(1);
}
