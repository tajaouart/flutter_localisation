# Flutter Localization Generator

This tool automates the generation of localization files in a Flutter project. It updates the `l10n.yaml` file, validates ARB files, and runs `flutter gen-l10n` to generate the necessary Dart files for localization.

## Prerequisites

Ensure you have the following installed:
- **Flutter** (latest stable version)
- **Dart** (included with Flutter)
- **Logging package** (pre-installed with Flutter)

## Installation

1. Clone this repository or download the script.
2. Move the script to your project’s `bin/` directory.
3. Make the script executable:
   ```sh
   chmod +x bin/flutter_localisation.dart
   ```

## Usage

To generate localization files, run:
```sh
dart run bin/flutter_localisation.dart <flavors-folder> <flavor-name>
```

### Example:
```sh
dart run bin/flutter_localisation.dart lib/l10n default
```

This will:
1. Check if the specified flavor folder exists.
2. Validate or create the `l10n.yaml` file.
3. Validate that `.arb` files exist in the folder.
4. Run `flutter gen-l10n` to generate the localization files.

## Expected Folder Structure
Ensure your localization files are structured as follows:
```
lib/
 ├── l10n/
 │    ├── default/
 │    │    ├── app_en.arb
 │    │    ├── app_fr.arb
 │    ├── other_flavor/
 │         ├── app_en.arb
 │         ├── app_es.arb
 ├── localization/
 │    ├── generated/
 │         ├── app_localizations.dart
```

### Sample ARB File (`app_en.arb`):
```json
{
  "@@locale": "en",
  "hello_world": "Hello, World!"
}
```

### Output
After running the script, you should find the generated localization files inside `lib/localization/generated/`.

## Error Handling
- **Missing arguments**: Ensure both `<flavors-folder>` and `<flavor-name>` are provided.
- **Invalid folder path**: The specified flavor folder must exist.
- **Missing ARB files**: The script requires `.arb` files in the flavor directory.
- **Flutter command errors**: If `flutter gen-l10n` fails, check for syntax issues in `l10n.yaml` or ARB files.

## Notes
- This tool modifies `l10n.yaml`. If you prefer using command-line options, remove the file.
- Supports multiple flavors by specifying different folders.

## License
This tool is open-source and available for modification.

