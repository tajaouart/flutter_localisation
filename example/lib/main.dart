import 'package:material_ui/material_ui.dart';
import 'package:flutter_localisation/flutter_localisation.dart';

import 'home_page.dart';
import 'localization/generated/app_localizations.dart';

// Live updates need a key from your workspace settings:
// flutter run --dart-define=FL_SECRET_KEY=sk_live_... --dart-define=FL_PROJECT_ID=<id>
// Without them the app runs on the bundled ARBs only.
const _secretKey = String.fromEnvironment('FL_SECRET_KEY');
const _projectId = int.fromEnvironment('FL_PROJECT_ID');
const _flavorName = String.fromEnvironment(
  'FL_FLAVOR',
  defaultValue: 'Default',
);

final _flutterLocalisationService = TranslationService(
  config: const TranslationConfig(
    enableLogging: true,
    secretKey: _secretKey == '' ? null : _secretKey,
    supportedLocales: ['en', 'es', 'es-MX', 'fr', 'ar', 'zh', 'zh-Hant'],
    projectId: _projectId == 0 ? null : _projectId,
    flavorName: _flavorName,
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _flutterLocalisationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _currentLocale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterLocalisation Example',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: _currentLocale,
      // Not AppLocalizations.localizationsDelegates: gen-l10n still lists the
      // flutter_localizations delegates, which material_ui widgets do not read.
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          return TranslationProvider(
            service: _flutterLocalisationService,
            generatedLocalizations: AppLocalizations.of(context),
            child: HomePage(
              flavorName: _flavorName,
              onLanguageChange: (locale) {
                setState(() => _currentLocale = locale);
              },
            ),
          );
        },
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  final palette = Palette.of(brightness);
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      primary: palette.accent,
      surface: palette.surface,
    ),
    scaffoldBackgroundColor: palette.paper,
    dividerColor: palette.line,
    extensions: [palette],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    ),
  );
}

class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
  });

  final Color paper;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentSoft;

  static const light = Palette(
    paper: Color(0xFFF2F4F7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF172033),
    muted: Color(0xFF5E6778),
    line: Color(0xFFE1E5EC),
    accent: Color(0xFF0E7C66),
    accentSoft: Color(0xFFDDF1EB),
  );

  static const dark = Palette(
    paper: Color(0xFF0F141C),
    surface: Color(0xFF171E29),
    ink: Color(0xFFE8ECF2),
    muted: Color(0xFF98A2B3),
    line: Color(0xFF263041),
    accent: Color(0xFF3CC9A6),
    accentSoft: Color(0xFF173A33),
  );

  static Palette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 ? this : other ?? this;
}
