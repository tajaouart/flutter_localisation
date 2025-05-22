# Flutter Localization Tool

This project is a Dart-based localization tool tailored for [Flutter Localization SaaS](https://flutterlocalisation.com/) users. It handles ARB files and generates the corresponding Dart localization classes efficiently.

## Features

- Parses ARB localization files
- Generates strongly typed localization classes for Flutter
- Supports flavor-based localization structure
- Git integration (GitHub, GitLab, Bitbucket)

---

## Installation

1. Activate the package globally:

```bash
dart pub global activate flutter_localisation
```

2. Ensure the Dart bin directory is in your system’s PATH:

Add the following to your shell config file (e.g., `.bashrc` or `.zshrc`):

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

## Project Setup

Before generating localization files:

1. Link your project to a Git repository (GitHub, GitLab, or Bitbucket).
2. Clone the ARB file repository into your Flutter project directory.

## Usage

### Generate Localization Files

Run the following command to generate localization code for a specific flavor:

```bash
flutter_localisation [arb_directory] [flavor]
```

Example:
```bash
flutter_localisation myArbs usa
```

## Flutter Project Setup

1. Add dependencies:

```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

2. Enable code generation in `pubspec.yaml`:

```yaml
flutter: 
  generate: true
```

## Integrate in Your Flutter App

In your `MaterialApp` widget:

```dart
MaterialApp(
  title: 'Localizations Sample App',
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
)
```

Example usage in AppBar:

```dart
appBar: AppBar(
  title: Text(AppLocalizations.of(context)!.helloWorld),
),
```
