import 'package:flutter/material.dart';
import 'package:flutter_localisation/saas_translations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_page.dart';
import 'localization/generated/app_localizations.dart';

final _saasService = SaaSTranslationService(
  config: const SaaSTranslationConfig(
    enableLogging: true,
    apiBaseUrl: 'http://localhost:8000',
    secretKey: "sk_live_Z095M95SsXi-LqI39vduaa9Vhc-Zjug8oXjnST-DGNs",
    supportedLocales: ['en', 'es'],
    projectId: 31,
    flavorName: 'Default',
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _saasService.initialize();
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
      title: 'SaaS Translations Example',
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
          return SaaSTranslationProvider(
            service: _saasService,
            generatedLocalizations: localizations,
            child: HomePage(onLanguageChange: _changeLanguage),
          );
        },
      ),
    );
  }
}
