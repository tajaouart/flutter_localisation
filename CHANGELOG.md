# Changelog

## [2.7.2] - 2026-11-12
### Fixed
- **Removing a language no longer breaks `flutter analyze`.** `flutter gen-l10n` never
  deletes the file of a language it stopped generating, so the old
  `app_localizations_<language>.dart` stayed behind and failed the analyzer as soon as a
  key was added. The generator now removes per-language files no ARB asks for.

## [2.7.1] - 2026-11-11
### Docs
- New pub.dev page: shorter README, light mode screenshots and a language GIF of the
  example app.

### Fixed
- **A live update renders exactly like the bundled string.** The ICU engine behind live
  updates is a real parser now: nested `plural` and `select`, every plural category
  (`zero`, `one`, `two`, `few`, `many`, `other`), exact `=N` cases, and any spacing
  around the keywords. It picks cases with the same rules as `flutter gen-l10n`.
- Dates, currencies, compact numbers and percentages in a live update keep their format.
  The generator reads each placeholder's `type`, `format`, `optionalParameters` and
  `isCustomDateFormat` from the template ARB and passes them to the translator.
- A malformed live update shows the bundled string instead of raw ICU text.
- A `double` passed as a plural count no longer throws.
- On a regional device, a key found only in the base language (`es` for `es-MX`) is
  rendered from that language's template instead of showing `KEY_NOT_FOUND`.
- The generator reads declarations that wrap over several lines, and warns when an ARB
  key has the same name as a `Translator` member (`refresh`, `translate`, ...), which
  hides it from `context.tr`.

## [2.7.0] - 2026-11-11
### Fixed
- **A live update shows as soon as it lands.** `TranslationService` is now a `ChangeNotifier`
  and `TranslationProvider` rebuilds its dependents when an update is applied or the cache is
  cleared. Before, the fetch finished after the first frame and the new strings only appeared
  on the next launch.

### Changed
- The package imports `package:flutter/widgets.dart` only, never Material, so the move of
  Material and Cupertino to the `material_ui` / `cupertino_ui` packages does not affect it.
- `dispose()` can be called more than once.

## [2.6.1] - 2026-10-15
### Changed
- README only: current version pin, key-based plan limits (500 keys on Free,
  languages free on every plan), yearly and invoice billing, and the `fl` CLI
  steps next to the `arbs` command. No code change.

## [2.6.0] - 2026-08-22
### Fixed
- **Live-update overrides now reach regional and script locales.** The lookup
  used `locale.languageCode` alone, so a device on `pt-BR` read the European
  Portuguese overrides, and a project holding only `pt-BR` received none at all
  while the dashboard showed them published. Resolution now walks
  `zh-Hant-HK` → `zh-Hant` → `zh-HK` → `zh`, accepts either separator (the
  project stores `pt-BR`; an ARB's `@@locale` is `pt_BR`), and ends at the base
  language so a variant device still gets base-language copy. The whole-locale
  fetch behind the ICU processor resolves through the same chain, so a screen
  can no longer take one string from `pt-BR` and the rest from `pt`.

## [2.5.1] - 2026-07-14
### Fixed
- **Apostrophes no longer break codegen.** A freshly-created `l10n.yaml` now defaults to
  `use-escaping: false` (matching Flutter gen-l10n's own default). With escaping enabled, a
  lone apostrophe in a translation — French `l'appareil` / `Conditions d'utilisation`, Italian
  `l'app` — was parsed as an ICU quote delimiter and failed generation with *"Unmatched single
  quotes"*. Since almost all real-world copy contains apostrophes and almost none needs ICU
  literal-escaping, `false` is the safe default. Existing `l10n.yaml` files are untouched (only
  `arb-dir` is rewritten), so projects that rely on escaping can keep `use-escaping: true`.

## [2.5.0] - 2026-07-07
### Changed
- **The `fl` CLI and `fl_mcp` MCP server moved to a new package,
  [`flutter_localisation_cli`](https://pub.dev/packages/flutter_localisation_cli).** This keeps
  the runtime library lean (no `args` dependency) and lets the tooling install and run without
  the Flutter SDK. If you used `dart pub global activate flutter_localisation` for `fl`/`fl_mcp`,
  switch to `dart pub global activate flutter_localisation_cli`. The runtime API and the
  `flutter_localisation` / `generate` codegen executables are unchanged.


## [2.4.1] - 2026-07-07
### Fixed
- **MCP launch command in the docs.** `dart pub global run flutter_localisation:fl_mcp` fails
  ("requires the Flutter SDK, unsupported for global executables") because the package depends
  on Flutter. Use the installed `fl_mcp` shim instead (`~/.pub-cache/bin/fl_mcp`). README and
  the Claude Code / Desktop configs updated.
- **`fl projects` / token-only commands no longer require a `flutterlocalisation.json`.** A
  missing project config in the working tree is now fine — `projects`/`login` and any
  `--project <name>`/single-project command work with just `--token` (base URL defaults to
  production). An explicitly-passed `--config` that doesn't exist still errors.


## [2.4.0] - 2026-07-07
### Fixed
- **`fl delete <key>` (and MCP `delete_string` without a locale) now deletes the whole key.**
  Previously it removed each locale's translation but left an empty key behind. Backed by a new
  `POST /api/projects/<id>/translation_keys/delete/` endpoint. Deleting a single locale
  (`--locale fr`) still removes just that translation.
### Added
- **Git-sync warnings.** If the backend's GitHub token has expired (ARB pushes failing),
  `fl projects` shows a "⚠️ git sync disconnected — reconnect GitHub in the dashboard" note,
  MCP `list_projects` includes a `warning`, and any "token expired" error now prints a clear
  hint to reconnect. Reconnect from the dashboard (project → Repo).

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