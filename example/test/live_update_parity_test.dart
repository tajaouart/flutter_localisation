import 'dart:convert';
import 'dart:io';

import 'package:example/generated_translation_methods.dart';
import 'package:example/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves every bundled ARB string as if it had arrived as a live update.
class _ArbOverrides extends TranslationService {
  _ArbOverrides(this.byLocale);

  final Map<String, Map<String, String>> byLocale;

  @override
  String? getOverride(String locale, String key) => byLocale[locale]?[key];

  @override
  bool get isLoggingEnabled => false;
}

/// Stands in for AppLocalizations so a live update that fails to render
/// cannot hide behind the bundled string.
class _NoFallback {
  _NoFallback(this.localeName);

  final String localeName;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('fell back to the bundled ${invocation.memberName}');
}

Map<String, Map<String, String>> _readArbs() {
  return {
    for (final file in Directory('arbs/usa').listSync().whereType<File>())
      if (file.path.endsWith('.arb'))
        file.uri.pathSegments.last
            .replaceFirst('app_', '')
            .replaceFirst('.arb', ''): {
          for (final entry in (jsonDecode(
            file.readAsStringSync(),
          ) as Map<String, dynamic>).entries)
            if (!entry.key.startsWith('@')) entry.key: entry.value as String,
        },
  };
}

const _counts = [0, 1, 2, 3, 5, 10, 11, 21, 99, 100, 101, 1000, 1000000];
const _genders = ['male', 'female', 'other', 'unknown'];
final _dates = [
  DateTime(2026, 1, 5, 9, 30),
  DateTime(2026, 11, 11, 18, 5),
  DateTime(1999, 12, 31, 23, 59),
];
const _amounts = [0.0, 1.0, 9.99, 1234.5, 1000000.99];
const _bigCounts = [0, 7, 999, 1234, 15300, 1500000, 2000000000];
const _ratios = [0.0, 0.05, 0.5, 0.875, 1.0];

/// Every message rendered over a range of values, keyed by a readable label.
/// Written twice because extension methods do not dispatch on `dynamic`.
Map<String, String> _renderBundled(AppLocalizations t) => {
  'appTitle': t.appTitle,
  'simpleGreeting': t.simpleGreeting,
  'refreshTranslations': t.refreshTranslations,
  'hello': t.hello('Sam'),
  'welcomeMessage': t.welcomeMessage('Sam'),
  for (final n in _counts) 'itemsInCart($n)': t.itemsInCart(n),
  for (final g in _genders) 'notificationFrom($g)': t.notificationFrom(g),
  for (final g in _genders)
    for (final n in _counts) 'friendsInvited($g, $n)': t.friendsInvited(g, n),
  for (final d in _dates) 'lastSeen($d)': t.lastSeen(d),
  for (final d in _dates) 'eventStarts($d)': t.eventStarts(d),
  for (final a in _amounts) 'orderTotal($a)': t.orderTotal(a),
  for (final n in _bigCounts) 'downloads($n)': t.downloads(n),
  for (final r in _ratios) 'progress($r)': t.progress(r),
};

Map<String, String> _renderLive(Translator t) => {
  'appTitle': t.appTitle,
  'simpleGreeting': t.simpleGreeting,
  'refreshTranslations': t.refreshTranslations,
  'hello': t.hello('Sam'),
  'welcomeMessage': t.welcomeMessage('Sam'),
  for (final n in _counts) 'itemsInCart($n)': t.itemsInCart(n),
  for (final g in _genders) 'notificationFrom($g)': t.notificationFrom(g),
  for (final g in _genders)
    for (final n in _counts) 'friendsInvited($g, $n)': t.friendsInvited(g, n),
  for (final d in _dates) 'lastSeen($d)': t.lastSeen(d),
  for (final d in _dates) 'eventStarts($d)': t.eventStarts(d),
  for (final a in _amounts) 'orderTotal($a)': t.orderTotal(a),
  for (final n in _bigCounts) 'downloads($n)': t.downloads(n),
  for (final r in _ratios) 'progress($r)': t.progress(r),
};

void main() {
  final arbs = _readArbs();

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('a live update renders like the bundled ARB in $locale', (
      tester,
    ) async {
      late Map<String, String> bundled;
      late Map<String, String> live;

      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          child: Builder(
            builder: (context) {
              final generated = AppLocalizations.of(context);
              bundled = _renderBundled(generated);
              live = _renderLive(
                Translator(
                  context: context,
                  service: _ArbOverrides(arbs),
                  generatedLocalizations: _NoFallback(generated.localeName),
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(live.keys, bundled.keys);
      for (final key in bundled.keys) {
        expect(live[key], bundled[key], reason: '$locale $key');
      }
    });
  }

  testWidgets('a regional locale takes missing keys from its language', (
    tester,
  ) async {
    late String greeting;
    late String hello;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('es', 'MX'),
        delegates: const [
          AppLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            final t = Translator(
              context: context,
              service: _ArbOverrides({
                'es-MX': {'simpleGreeting': '¡Buen día, en vivo!'},
                'es': {'hello': '¡Hola {name}, en vivo!'},
              }),
              generatedLocalizations: AppLocalizations.of(context),
            );
            greeting = t.simpleGreeting;
            hello = t.hello('Sam');
            return const SizedBox();
          },
        ),
      ),
    );
    expect(greeting, '¡Buen día, en vivo!');
    expect(hello, '¡Hola Sam, en vivo!');
  });

  testWidgets('a malformed live update shows the bundled string', (
    tester,
  ) async {
    late String result;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: const [
          AppLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            result = Translator(
              context: context,
              service: _ArbOverrides({
                'en': {'itemsInCart': '{count, plural, =0{Nothing}'},
              }),
              generatedLocalizations: AppLocalizations.of(context),
            ).itemsInCart(3);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(result, '3 items');
  });
}
