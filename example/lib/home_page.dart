import 'package:example/generated_translation_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localisation/flutter_localisation.dart';

/// Example home page showing SaaS translations in action
class HomePage extends StatefulWidget {
  final Function(Locale) onLanguageChange;

  const HomePage({super.key, required this.onLanguageChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _cartItems = 0;

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    final translationsService = context.translations!;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.appTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [_buildLanguageSelector(currentLocale)],
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
                                translationsService.getCacheStatus().isNotEmpty
                                    ? Colors.green
                                    : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            translationsService.getCacheStatus().isNotEmpty
                                ? 'SaaS overrides active (cached & synced)'
                                : 'Using standard localizations',
                            style: TextStyle(
                              color:
                                  translationsService
                                          .getCacheStatus()
                                          .isNotEmpty
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (translationsService.getCacheStatus().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...translationsService.getCacheStatus().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            '• ${entry.key}: ${entry.value} overrides (cached)',
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
                              'Auto-syncing in background',
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
