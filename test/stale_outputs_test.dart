import 'dart:io';

import 'package:flutter_localisation/src/stale_outputs.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('staleLocaleFiles', () {
    const List<String> generated = <String>[
      'lib/gen/app_localizations.dart',
      'lib/gen/app_localizations_en.dart',
      'lib/gen/app_localizations_es.dart',
      'lib/gen/app_localizations_de.dart',
      'lib/gen/other_helper.dart',
    ];

    test('a language with no ARB left is stale', () {
      expect(
        staleLocaleFiles(
          generatedFiles: generated,
          outputFile: 'app_localizations.dart',
          locales: <String>['en', 'es_MX', 'es'],
        ),
        <String>['lib/gen/app_localizations_de.dart'],
      );
    });

    test('a regional ARB keeps its language file', () {
      expect(
        staleLocaleFiles(
          generatedFiles: generated,
          outputFile: 'app_localizations.dart',
          locales: <String>['en', 'es-MX', 'de_AT'],
        ),
        isEmpty,
      );
    });

    test('files that are not per-language outputs are never touched', () {
      expect(
        staleLocaleFiles(
          generatedFiles: generated,
          outputFile: 'app_localizations.dart',
          locales: <String>[],
        ),
        isNot(contains('lib/gen/app_localizations.dart')),
      );
      expect(
        staleLocaleFiles(
          generatedFiles: generated,
          outputFile: 'app_localizations.dart',
          locales: <String>[],
        ),
        isNot(contains('lib/gen/other_helper.dart')),
      );
    });

    test('a custom output file name is respected', () {
      expect(
        staleLocaleFiles(
          generatedFiles: <String>['l10n_fr.dart', 'app_localizations_fr.dart'],
          outputFile: 'l10n.dart',
          locales: <String>['en'],
        ),
        <String>['l10n_fr.dart'],
      );
    });
  });

  group('arbLocale', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('arb_locale_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File write(final String name, final String body) =>
        File(path.join(dir.path, name))..writeAsStringSync(body);

    test('reads @@locale first', () {
      final File arb = write('my_app_x.arb', '{"@@locale": "pt_BR"}');
      expect(arbLocale(arb), 'pt_BR');
    });

    test('falls back to the file name', () {
      expect(arbLocale(write('app_es_MX.arb', '{}')), 'es_MX');
      expect(arbLocale(write('app_en.arb', 'not json')), 'en');
    });
  });
}
