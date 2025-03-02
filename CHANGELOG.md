# Changelog

## [1.0.0] - 2024-06-08
### Added
- Initial release of `flutter_localisation`.
- Script to generate localization files based on provided flavor.
- Support for updating existing `l10n.yaml` with the correct flavor.
- Error handling for missing flavors.
- Automatic creation of `l10n.yaml` from scratch if it does not exist.
- Logging of errors during file reading and writing.
- Tests for various scenarios including:
    - Updating `l10n.yaml` with the correct flavor.
    - Logging an error if no flavor is provided.
    - Creating `l10n.yaml` from scratch if it does not exist.
    - Handling errors during file reading and writing.
    - Logging error if ARB directory does not exist.
- Documentation for installation and usage.

## 1.0.1
- Fixed Path issue.