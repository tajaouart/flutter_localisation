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
- 
## 1.0.2
- use escaping.

## 1.0.3
- Updated ReadMe & example app.

## 2.1.0
### Added
- Automatic git pull before generating localization files.
- Comprehensive dartdoc comments for public API.
- Extensive test coverage with 60+ tests.

### Changed
- Made initialize() optional for free users.
- Improved code formatting and organization.

### Fixed
- All linting issues for pub.dev compliance.
- Git tracking cleanup.

## 2.0.0
- Support Live update feature.