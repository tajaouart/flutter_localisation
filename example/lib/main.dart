// example/lib/main.dart
import 'package:example/generated_saas_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localisation/saas_translations.dart';
// 1. Import your generated localizations (standard Flutter)
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/generated/app_localizations.dart';
// 2. Import SaaS translations package

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 3. Create SaaS service instance
  final _saasService = SaaSTranslationService(
    config: const SaaSTranslationConfig.development(),
  );

  Key _appKey = UniqueKey();
  Locale _currentLocale = const Locale('en'); // Add locale state

  @override
  void initState() {
    super.initState();

    // 4. Listen for translation updates
    _saasService.addListener(_onTranslationsUpdated);

    // 5. Fetch initial translations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saasService.fetchUpdates(_currentLocale.languageCode);
    });
  }

  @override
  void dispose() {
    _saasService.removeListener(_onTranslationsUpdated);
    super.dispose();
  }

  void _onTranslationsUpdated() {
    if (mounted) {
      setState(() {
        _appKey = UniqueKey(); // Rebuild app with new translations
      });
    }
  }

  // Add language change method
  void _changeLanguage(Locale newLocale) {
    setState(() {
      _currentLocale = newLocale;
      _appKey = UniqueKey(); // Force rebuild with new locale
    });

    // Fetch SaaS translations for new language
    _saasService.fetchUpdates(newLocale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey,
      title: 'SaaS Translations Example',
      locale: _currentLocale, // Use current locale
      // Standard Flutter localization setup
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,

      // Create the home page directly instead of using builder
      home: Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);

          // Wrap with SaaS provider
          return SaaSTranslationProvider(
            service: _saasService,
            generatedLocalizations: localizations,
            child: HomePage(
              onLanguageChange: _changeLanguage,
            ), // Pass language change function
          );
        },
      ),
    );
  }
}

/// Example home page showing SaaS translations in action
class HomePage extends StatefulWidget {
  final Function(Locale) onLanguageChange; // Add language change callback

  const HomePage({super.key, required this.onLanguageChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _cartItems = 0;

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        // 7. Use SaaS translations - super simple!
        title: Text(context.tr.appTitle), // 🎯 Simple usage!
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Language selector in AppBar
          _buildLanguageSelector(currentLocale),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language instruction card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Use the language selector (🌐) in the top-right to switch between English and Spanish!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SaaS Translations Demo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current Language: ${currentLocale.languageCode.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Show different types of translations
                    Text('Greeting: ${context.tr.simpleGreeting}'),
                    const SizedBox(height: 8),
                    Text('Hello: ${context.tr.hello("World")}'),
                    const SizedBox(height: 8),
                    Text('Welcome: ${context.tr.welcomeMessage("Developer")}'),
                    const SizedBox(height: 8),
                    Text('Cart: ${context.tr.itemsInCart(_cartItems)}'),
                    const SizedBox(height: 8),
                    Text(
                      'ICU Processing: ${_cartItems == 0
                          ? "Zero case"
                          : _cartItems == 1
                          ? "Singular"
                          : "Plural"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cart controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed:
                      () => setState(
                        () => _cartItems = (_cartItems - 1).clamp(0, 10),
                      ),
                  child: const Text('-'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$_cartItems items'),
                ),
                ElevatedButton(
                  onPressed:
                      () => setState(
                        () => _cartItems = (_cartItems + 1).clamp(0, 10),
                      ),
                  child: const Text('+'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // SaaS control - FIXED: Use refreshButton text, refresh() method
            ElevatedButton.icon(
              onPressed: () async {
                await context.tr.refreshArbFiles(); // ✅ Method call
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Translations refreshed!')),
                  );
                }
              },
              icon: const Icon(Icons.cloud_download),
              label: Text(context.tr.refresh), // ✅ Text property (fixed!)
            ),

            const SizedBox(height: 20),

            // Debug info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings_system_daydream, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'SaaS Translation Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                context.tr.cacheStatus.isNotEmpty
                                    ? Colors.green
                                    : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr.cacheStatus.isNotEmpty
                                ? 'SaaS overrides active (AppLocalizations2 processing)'
                                : 'Using standard localizations',
                            style: TextStyle(
                              color:
                                  context.tr.cacheStatus.isNotEmpty
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (context.tr.cacheStatus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...context.tr.cacheStatus.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            '• ${entry.key}: ${entry.value} overrides',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ICU plurals, selects & formatting supported',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Language selector widget
  Widget _buildLanguageSelector(Locale currentLocale) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: DropdownButton<Locale>(
        value: currentLocale,
        icon: const Icon(Icons.language, color: Colors.white),
        underline: const SizedBox.shrink(),
        dropdownColor: Colors.grey[850],
        onChanged: (Locale? newLocale) {
          if (newLocale != null) {
            widget.onLanguageChange(newLocale);
          }
        },
        items: const [
          DropdownMenuItem(
            value: Locale('en'),
            child: Text('🇺🇸 English', style: TextStyle(color: Colors.white)),
          ),
          DropdownMenuItem(
            value: Locale('es'),
            child: Text('🇪🇸 Español', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
