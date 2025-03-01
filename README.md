# Flutter Localization Tool

This project is a Dart-based localization tool tailored for [Flutter Localization SaaS](https://flutterlocalization.com/) users. It handles ARB files and generates the corresponding Dart localization classes efficiently.

---

## Installation

1. Clone the repository:

git clone https://github.com/your-repo/flutter-localisation.git  
cd flutter-localisation

2. Install Dart and Flutter dependencies:

dart pub get  
flutter pub get

---

## Usage

### Running the Localization Tool

To generate localization files for a specific flavor, run the following command:

dart run bin/flutter_localisation.dart <flavors-folder> <flavor-name>

Example:

dart run bin/flutter_localisation.dart lib/l10n test_flavor

### Key Steps

1. **Create ARB Files**:  
   Add localization ARB files in the relevant flavor folder (e.g., `lib/l10n/test_flavor/app_en.arb`).

2. **Ensure `flutter: generate: true` in `pubspec.yaml`**:  
   Add the following section in your `pubspec.yaml`:

flutter:  
generate: true