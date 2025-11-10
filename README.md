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

## Quick Start

### Step 1: Set Up Project on Dashboard

1. Sign up at [flutterlocalisation.com](https://flutterlocalisation.com) and create a project
2. Add languages and translation keys via the web interface
3. Connect your Git repository (GitHub, GitLab, or Bitbucket)
4. The backend automatically generates ARB files and pushes them to your connected Git repo

### Step 2: Clone ARB Files to Your Flutter Project

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

### Step 3: Generate Localization Code

Run the CLI tool to generate type-safe Dart code from the ARB files:

```bash
flutter_localisation arbs production
```

Replace `production` with your flavor name. This generates all the necessary localization code.

### Step 4: Configure Your Flutter App

```dart
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:your_app/localization/generated/app_localizations.dart';
import 'package:your_app/generated_translation_methods.dart';

void main() {
  final translationService = TranslationService(
    config: TranslationConfig.freeUser(),
  );

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

#### Optional: Enable Live Updates (Paid Plans)

If you have a paid plan and want live updates at runtime:

1. Get your API credentials from the dashboard:
   - Go to workspace settings and copy your **Live Update API Key** (`sk_live_...`)
   - Note your **Project ID** from project settings

2. Update your configuration:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final translationService = TranslationService(
    config: TranslationConfig.paidUser(
      secretKey: 'sk_live_your_key_here',
      projectId: 31,
      flavorName: 'production',
      supportedLocales: ['en', 'es', 'fr'],
      enableLogging: true,
    ),
  );

  // Initialize to enable live updates
  await translationService.initialize();

  runApp(MyApp(translationService: translationService));
}
```

### Step 5: Use Translations in Your Code

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

### Step 6: Update Translations

When you need to update translations:

1. Edit translations on the dashboard at flutterlocalisation.com
2. Changes are automatically pushed to Git
3. Run: `flutter_localisation arbs production` (automatically pulls latest changes from Git)
4. For paid plans with live updates, your app will fetch changes automatically on next launch

---

## Generate Localization After ARB Changes

Whenever you update ARB files:

```bash
flutter_localisation arbs your_flavor_name
```

This command automatically:
- Pulls latest changes from Git (if the ARB folder is a Git repository)
- Regenerates standard Flutter localization files in `lib/localization/generated/`
- Generates extension methods file at `lib/generated_translation_methods.dart`

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
