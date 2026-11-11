import 'package:flutter/widgets.dart';
import 'package:flutter_localisation/src/api/locale_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('localeCacheKeys', () {
    test('a bare language asks for itself only', () {
      expect(localeCacheKeys(const Locale('fr')), <String>['fr']);
    });

    test('a regional locale tries the variant before the base language', () {
      expect(
        localeCacheKeys(const Locale('pt', 'BR')),
        <String>['pt-BR', 'pt_BR', 'pt'],
      );
    });

    test('both separators are offered, because the cache uses either', () {
      // The project stores `pt-BR`; an ARB's `@@locale` is `pt_BR`.
      final List<String> keys = localeCacheKeys(const Locale('pt', 'BR'));
      expect(keys, contains('pt-BR'));
      expect(keys, contains('pt_BR'));
      expect(keys.indexOf('pt-BR'), lessThan(keys.indexOf('pt')));
    });

    test('a script variant resolves before the base language', () {
      const Locale traditional =
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      expect(
        localeCacheKeys(traditional),
        <String>['zh-Hant', 'zh_Hant', 'zh'],
      );
    });

    test('script and region together go most specific first', () {
      const Locale hongKong = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'HK',
      );
      expect(
        localeCacheKeys(hongKong),
        <String>[
          'zh-Hant-HK',
          'zh_Hant_HK',
          'zh-Hant',
          'zh_Hant',
          'zh-HK',
          'zh_HK',
          'zh',
        ],
      );
    });

    test('normalises casing to the form the project stores', () {
      expect(
        localeCacheKeys(const Locale('PT', 'br')),
        <String>['pt-BR', 'pt_BR', 'pt'],
      );
    });

    test('keeps a numeric UN M.49 region as digits', () {
      expect(
        localeCacheKeys(const Locale('es', '419')),
        <String>['es-419', 'es_419', 'es'],
      );
    });
  });
}
