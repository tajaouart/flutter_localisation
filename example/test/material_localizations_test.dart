import 'package:example/localization/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as sdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<MaterialLocalizations?> _materialStrings(
  WidgetTester tester,
  List<LocalizationsDelegate<dynamic>> delegates,
) async {
  MaterialLocalizations? found;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          found = Localizations.of<MaterialLocalizations>(
            context,
            MaterialLocalizations,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return found;
}

void main() {
  testWidgets('material_ui widgets get Spanish strings from its delegates', (
    WidgetTester tester,
  ) async {
    final MaterialLocalizations? l = await _materialStrings(
      tester,
      <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
    );
    expect(l?.okButtonLabel, 'ACEPTAR');
  });

  testWidgets('the gen-l10n delegate list does not reach material_ui widgets', (
    WidgetTester tester,
  ) async {
    final MaterialLocalizations? l = await _materialStrings(
      tester,
      <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        sdk.GlobalMaterialLocalizations.delegate,
        sdk.GlobalWidgetsLocalizations.delegate,
      ],
    );
    expect(tester.takeException(), isNotNull);
    expect(l, isNull);
  });
}
