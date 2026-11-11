import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_page.dart';
import 'localization/generated/app_localizations.dart';

// Live updates need a key from your workspace settings:
// flutter run --dart-define=FL_SECRET_KEY=sk_live_... --dart-define=FL_PROJECT_ID=<id>
// Without them the app runs on the bundled ARBs only.
const _secretKey = String.fromEnvironment('FL_SECRET_KEY');
const _projectId = int.fromEnvironment('FL_PROJECT_ID');
const _flavorName = String.fromEnvironment('FL_FLAVOR', defaultValue: 'Default');

final _flutterLocalisationService = TranslationService(
  config: const TranslationConfig(
    enableLogging: true,
    secretKey: _secretKey == '' ? null : _secretKey,
    supportedLocales: ['en', 'es'],
    projectId: _projectId == 0 ? null : _projectId,
    flavorName: _flavorName,
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _flutterLocalisationService.initialize();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _currentLocale = const Locale('en');

  void _changeLanguage(Locale newLocale) {
    setState(() {
      _currentLocale = newLocale;
      // Language change will naturally rebuild with new translations
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterLocalisation Translations Example',
      locale: _currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return TranslationProvider(
            service: _flutterLocalisationService,
            generatedLocalizations: localizations,
            child: HomePage(onLanguageChange: _changeLanguage),
          );
        },
      ),
    );
  }
}
