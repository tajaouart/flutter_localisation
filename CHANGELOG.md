# Changelog

## [2.3.0] - 2026-07-07
### Added
- **Project discovery — pick projects by name, no numeric ids.** The API token is a workspace
  credential, so the CLI and MCP now list your projects and resolve them by name:
  - `fl projects` lists accessible projects with their flavors and locales.
  - `fl` gained a global `--project <name|id>`; `project_id` in `flutterlocalisation.json` is now
    optional (a single project resolves automatically; or set `"project": "<name>"`).
  - MCP: new `list_projects` tool; every tool accepts optional `project`/`flavor` by name.
    `FL_PROJECT_ID` is no longer required (use `FL_PROJECT` for a default, or none at all).
- Backed by a new `GET /api/projects/` endpoint that lists the caller's projects.

## [2.2.0] - 2026-07-06
### Added
- **`fl` management CLI** — add, edit, delete, and AI-translate translation keys straight from
  the terminal (full dashboard parity), then `git pull` the ARBs. Commands: `login`, `add`
  (`--translate`), `edit`, `delete`, `translate`, `status`, `pull`; global `--dry-run`/`--json`.
- **`fl_mcp` MCP server** — a Model Context Protocol server (stdio) exposing the same operations
  as tools, so Claude can manage your translations. Mutating tools are preview-by-default and
  only write when called with `apply: true`.
- Auth uses a scoped `flk_live_…` API token (created in the dashboard → API Keys), resolved from
  `--token` / `$FL_API_TOKEN` / `~/.config/flutterlocalisation/credentials.json` (chmod 600).
- New `args` dependency (used only by the `fl`/`fl_mcp` executables, not the runtime library).

## [2.1.5] - 2026-06-28
### Docs
- Refreshed the README product screenshots with the current dashboard UI (projects, translation editor, team, analytics) and cache-busted the image URLs.

## [2.1.4] - 2026-06-28
### Docs
- Added a "See it in action" section to the README with product screenshots (dashboard, the connect → translate → sync flow, visual editor, and team collaboration).

## [2.1.3] - 2026-06-28
### Changed
- Rewrote the package description for clarity and discoverability (i18n/l10n keywords).
- Added `homepage`, `documentation`, `issue_tracker`, and `topics` (localization, internationalization, i18n, l10n, intl) to improve pub.dev discovery.
### Fixed
- Replaced the LICENSE file with the full MIT license text so the license is correctly detected (matches the README, which already states MIT).
- Moved `mockito` from `dependencies` to `dev_dependencies` (it is only used in tests).
- Removed a stray duplicate `README 2.md`.
### Docs
- Added pub.dev badges and links to the free online tools (ARB Editor, ARB Diff, l10n.yaml Generator, Locale Explorer).

## [2.1.2] - 2025-12-06
### Fixed
- Added missing `flutter_localizations` import in README documentation example
- Updated version reference in README to ^2.1.1
- Added `// ignore_for_file: non_constant_identifier_names` to generated code to suppress linting warnings

## [2.1.1] - 2025-12-01
### Added
- Automatic cache invalidation after code generation
- Automatic `flutter pub get` execution to refresh dependencies
- Clear warning message about needing to fully restart the app

### Changed
- CLI now automatically deletes `.dart_tool/` directory and `.flutter-plugins-dependencies` after generation
- Does NOT delete `build/` folder to avoid slow rebuilds (users must fully restart app instead)
- Simplified workflow - users only need to run `flutter_localisation arbs <flavor>` and fully restart their app
- Updated documentation to emphasize the need for full app restart (not hot reload/restart)

### Fixed
- Stale Dart analysis cache causing "method not found" errors on generated translation keys
- Improved user experience by automating cache cleanup

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