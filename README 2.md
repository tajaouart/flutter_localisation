# Flutter Localisation

A complete Flutter localization solution that combines:
- **CLI tool** for generating type-safe localization code from ARB files
- **Live updates** via [flutterlocalisation.com](https://flutterlocalisation.com) (optional, paid feature)
- **Flavor-based** localization structure for multi-environment apps

## Features

### Free (Local Usage)
- Generate strongly typed localization classes from ARB files
- Support for multiple flavors (dev, staging, production, etc.)
- Automatic code generation with type-safe methods
- Plural handling and parameterized strings
- Works completely offline

### Paid (with flutterlocalisation.com)
- **Manage translations** via web dashboard with your team
- **Live updates** - update translations without app releases
- **Git integration** - automatic ARB file sync (GitHub, GitLab, Bitbucket)
- **Translation memory** and AI-assisted translation
- **Team collaboration** with granular permissions
- **Multi-project** and multi-flavor management

---

## Installation

### 1. Install CLI Tool

```bash
dart pub global activate flutter_localisation
```

### 2. Add to PATH (if needed)

Add this to your shell config (`.bashrc`, `.zshrc`, etc.):

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### 3. Add to Your Flutter Project

```yaml
# pubspec.yaml
dependencies:
  flutter_localisation: ^2.0.0
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

Then run:
```bash
flutter pub get
```

---

## Quick Start (Free - Local Usage)

### Step 1: Create ARB Files

Create a folder structure for your translations:

```
your_project/
├── arbs/
│   ├── default/           # Your flavor name
│   │   ├── app_en.arb
│   │   ├── app_es.arb
│   │   └── app_fr.arb
```

Example `app_en.arb`:
```json
{
  "@@locale": "en",
  "@@last_modified": "2025-01-10T12:00:00.000000",
  "appTitle": "My App",
  "hello": "Hello {name}!",
  "@hello": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "itemCount": "{count, plural, =0{No items} =1{One item} other{{count} items}}",
  "@itemCount": {
    "placeholders": {
      "count": {"type": "int"}
    }
  }
}
```

### Step 2: Generate Localization Code

Run the CLI tool from your project root:

```bash
flutter_localisation arbs default
```

This will:
1. Create/update `l10n.yaml` pointing to your ARB files
2. Run `flutter gen-l10n` to generate standard Flutter localizations
3. Generate extension methods for easy usage with `context.tr`

### Step 3: Configure Your App

```dart
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:your_app/localization/generated/app_localizations.dart';
import 'package:your_app/generated_translation_methods.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize for free users (local only)
  final translationService = TranslationService.freeUser();
  await translationService.initialize();

  runApp(MyApp(translationService: translationService));
}

class MyApp extends StatelessWidget {
  final TranslationService translationService;

  const MyApp({required this.translationService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            service: translationService,
            generatedLocalizations: localizations,
            child: HomePage(),
          );
        },
      ),
    );
  }
}
```

### Step 4: Use in Your Widgets

```dart
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.appTitle),
      ),
      body: Column(
        children: [
          Text(context.tr.hello("World")),
          Text(context.tr.itemCount(5)),
        ],
      ),
    );
  }
}
```

---

## Full Workflow (with flutterlocalisation.com)

### Step 1: Create Account & Workspace

1. Sign up at [flutterlocalisation.com](https://flutterlocalisation.com)
2. Verify your email
3. Your workspace is automatically created

### Step 2: Create Project on Dashboard

1. Click **"New Project"**
2. Enter project name and select base language
3. Choose your subscription plan (Starter, Growth, or Business for live updates)

### Step 3: Add Languages & Flavors

1. In your project, click **"Add Language"** (e.g., Spanish, French)
2. Create flavors if needed (e.g., "production", "staging")
3. Add translation keys and values via the web interface

### Step 4: Connect Git Repository

1. In project settings, click **"Connect Git"**
2. Choose your platform (GitHub, GitLab, or Bitbucket)
3. Authorize the OAuth connection
4. Create or select a repository
5. ARB files will be automatically pushed to your repository

### Step 5: Clone ARB Files to Your Project

```bash
cd your_flutter_project
git clone <your-arb-repository-url> arbs
```

Your structure will look like:
```
your_project/
├── arbs/
│   ├── production/
│   │   ├── app_en.arb
│   │   ├── app_es.arb
│   └── staging/
│       ├── app_en.arb
│       ├── app_es.arb
```

### Step 6: Get Your API Credentials

1. Go to your workspace settings
2. Copy your **Live Update API Key** (format: `sk_live_...`)
3. Note your **Project ID** (shown in project settings)

### Step 7: Configure Your Flutter App

```dart
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:your_app/localization/generated/app_localizations.dart';
import 'package:your_app/generated_translation_methods.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with API credentials
  final translationService = TranslationService(
    config: TranslationConfig(
      secretKey: 'sk_live_your_key_here',  // From dashboard
      projectId: 31,                        // From dashboard
      flavorName: 'production',             // Your flavor
      supportedLocales: ['en', 'es', 'fr'],
      enableLogging: true,
    ),
  );

  await translationService.initialize();

  runApp(MyApp(translationService: translationService));
}

class MyApp extends StatefulWidget {
  final TranslationService translationService;

  const MyApp({required this.translationService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    // Fetch live updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.translationService.fetchAndApplyUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            service: widget.translationService,
            generatedLocalizations: localizations,
            child: HomePage(
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
```

### Step 8: Use Translations (Same as Free)

```dart
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.appTitle),
      ),
      body: Column(
        children: [
          // Simple string
          Text(context.tr.hello("World")),

          // Plurals
          Text(context.tr.itemCount(5)),

          // Manual refresh button
          ElevatedButton(
            onPressed: () {
              context.translations?.fetchAndApplyUpdates();
            },
            child: Text('Refresh Translations'),
          ),
        ],
      ),
    );
  }
}
```

### Step 9: Update Translations Live

1. Go to your dashboard at flutterlocalisation.com
2. Edit any translation
3. Changes are automatically pushed to Git
4. Your app fetches updates on next launch or manual refresh
5. **No app update required!**

---

## Generate Localization After ARB Changes

Whenever you update ARB files (locally or pulled from Git):

```bash
flutter_localisation arbs your_flavor_name
```

This regenerates:
- Standard Flutter localization files in `lib/localization/generated/`
- Extension methods file at `lib/generated_translation_methods.dart`

---

## Configuration Options

### TranslationConfig

```dart
TranslationConfig({
  String? secretKey,              // API key from dashboard (paid only)
  int? projectId,                 // Project ID from dashboard (paid only)
  String? flavorName,             // Flavor name (e.g., 'production')
  List<String>? supportedLocales, // Languages to fetch updates for
  bool enableLogging = true,      // Debug logs
})
```

### Factory Constructors

```dart
// For free users (local only)
TranslationService.freeUser()

// For paid users (manual config)
TranslationService(config: TranslationConfig(...))
```

---

## ARB File Format

### Basic Translation
```json
{
  "key": "value"
}
```

### With Placeholders
```json
{
  "greeting": "Hello {name}!",
  "@greeting": {
    "placeholders": {
      "name": {"type": "String"}
    }
  }
}
```

### With Plurals
```json
{
  "itemCount": "{count, plural, =0{No items} =1{One item} other{{count} items}}",
  "@itemCount": {
    "placeholders": {
      "count": {"type": "int"}
    }
  }
}
```

---

## How It Works

### For Free Users
1. You create ARB files locally
2. CLI tool generates type-safe Dart code
3. Translations are bundled with your app
4. Everything works offline

### For Paid Users
1. You manage translations on flutterlocalisation.com
2. Translations sync to Git automatically
3. CLI tool generates code from ARB files
4. **At runtime**, app checks for updates via API
5. If updates exist, they override bundled translations
6. Updates are cached for offline use
7. Falls back to bundled translations if API unavailable

---

## Team Collaboration (Paid)

### Add Team Members

1. Go to workspace settings
2. Click **"Add Member"**
3. Enter email and set permissions:
   - **Manager**: Full access to all projects
   - **Member**: Granular access per project/flavor
4. Set read/write permissions per flavor

### Permission Levels
- **Owner**: Full workspace access
- **Manager**: Can manage members and edit all projects
- **Member**: Custom access per project with optional write permissions

---

## Flavors & Multi-Environment

Use flavors to manage different environments:

```
arbs/
├── development/
│   ├── app_en.arb
│   └── app_es.arb
├── staging/
│   ├── app_en.arb
│   └── app_es.arb
└── production/
    ├── app_en.arb
    └── app_es.arb
```

Generate for specific flavor:
```bash
flutter_localisation arbs development
flutter_localisation arbs staging
flutter_localisation arbs production
```

Configure your app:
```dart
TranslationService(
  config: TranslationConfig(
    flavorName: 'production',  // Changes based on build flavor
    // ...
  ),
)
```

---

## Subscription Plans

| Feature | Free | Starter | Growth | Business |
|---------|------|---------|--------|----------|
| **Projects** | 2 | 6 | 20 | Unlimited |
| **Translations** | 1,000 | 15,000 | 75,000 | 300,000 |
| **Team Members** | 3 | 8 | 25 | 100 |
| **Live Updates** | ✗ | ✓ | ✓ | ✓ |
| **Git Integration** | Manual | ✓ | ✓ | ✓ |
| **AI Translation** | Limited | ✓ | ✓ | ✓ |

Visit [flutterlocalisation.com/pricing](https://flutterlocalisation.com/pricing) for current pricing.

---

## Example App

Check out the [example](./example) folder for a complete working implementation with:
- Multiple languages (English, Spanish, French)
- Multiple flavors (USA, Mexico)
- Live updates integration
- Language switching
- All translation types (simple, parameters, plurals)

---

## Troubleshooting

### ARB files not found
- Ensure the path is correct: `flutter_localisation <folder> <flavor>`
- Check that ARB files exist in the specified flavor folder
- ARB files must be named like `app_en.arb`, `app_es.arb`, etc.

### Generated code not working
- Run `flutter clean` and `flutter pub get`
- Ensure `flutter: generate: true` is in `pubspec.yaml`
- Check that `l10n.yaml` exists and points to correct ARB directory

### Live updates not working
- Verify your API key is correct (starts with `sk_live_`)
- Check project ID matches your dashboard
- Ensure you have a paid subscription
- Check network connectivity
- Enable logging to see detailed error messages

### Translations not updating
1. Update translations on dashboard
2. Pull latest ARB files from Git: `cd arbs && git pull`
3. Regenerate code: `flutter_localisation arbs your_flavor`
4. Rebuild your app or hot restart

---

## API Reference

### Context Extensions

```dart
// Access translator
context.tr.yourTranslationKey

// Access service
context.translations?.fetchAndApplyUpdates()
```

### TranslationService Methods

```dart
// Initialize service
await service.initialize()

// Fetch updates from API
await service.fetchAndApplyUpdates()

// Check if translation exists in cache
service.hasOverride('key', 'locale')

// Get cached translation
service.getOverride('key', 'locale')

// Get cache status
service.getCacheStatus()
```

---

## Contributing

Contributions are welcome! Please visit our [GitHub repository](https://github.com/tajaouart/flutter_localisation).

---

## Support

- **Documentation**: This README
- **Example App**: [./example](./example)
- **Issues**: [GitHub Issues](https://github.com/tajaouart/flutter_localisation/issues)
- **Website**: [flutterlocalisation.com](https://flutterlocalisation.com)

---

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.
