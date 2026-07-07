/// High-level operations composed from [ManagementClient].
///
/// These are the units the CLI and the MCP server both call, so behaviour (and the
/// add→translate→resolve sequencing) stays identical across surfaces. Each returns a
/// plain map so it can be printed by the CLI or returned as JSON by MCP. Every op supports
/// `dryRun` to compute the plan without mutating.
library;

import 'package:flutter_localisation/src/management/management_client.dart';

class OpResult {
  OpResult(this.ok, this.message, [this.data = const <String, dynamic>{}]);

  final bool ok;
  final String message;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => <String, dynamic>{'ok': ok, 'message': message, ...data};
}

class Operations {
  Operations(this.client, this.projectId, {this.flavor});

  final ManagementClient client;
  final int projectId;
  final String? flavor;

  /// Add a key with its base value, optionally AI-translating the other locales.
  Future<OpResult> add(
    final String key,
    final String baseValue, {
    final bool translate = false,
    final bool dryRun = false,
  }) async {
    if (dryRun) {
      return OpResult(true, 'DRY RUN: would add "$key" = "$baseValue"'
          '${translate ? ' and AI-translate all other locales' : ''}.');
    }
    await client.addKey(projectId, key, baseValue);

    if (!translate) {
      return OpResult(true, 'Added "$key".', <String, dynamic>{'key': key});
    }

    final ProjectData project = await client.getProject(projectId);
    final String? baseCode = project.baseLanguage(flavor)?.code;
    final List<int> targets = project
        .entriesForKey(key, flavorName: flavor)
        .where((final ({bool empty, int id, String locale}) e) => e.locale != baseCode)
        .map((final ({bool empty, int id, String locale}) e) => e.id)
        .toList();

    if (targets.isEmpty) {
      return OpResult(true, 'Added "$key" (no other locales to translate).',
          <String, dynamic>{'key': key},);
    }
    final BatchTranslateResult r = await client.aiBatchTranslate(targets);
    return OpResult(
      r.failedCount == 0,
      'Added "$key" and translated ${r.successCount}/${targets.length} locales'
      '${r.failedCount > 0 ? ' (${r.failedCount} failed)' : ''}.',
      <String, dynamic>{
        'key': key,
        'translated': r.successCount,
        'failed': r.failed.map((final ({String error, int id}) f) => <String, Object>{'id': f.id, 'error': f.error}).toList(),
      },
    );
  }

  /// Edit one locale's value (or plural/placeholder fields) of an existing key.
  Future<OpResult> edit(
    final String key,
    final String locale, {
    final String? value,
    final bool? isPluralEnabled,
    final String? zeroCase,
    final String? singularCase,
    final String? pluralCase,
    final String? pluralParam,
    final bool? isPlaceholdersEnabled,
    final Map<String, dynamic>? placeholders,
    final bool? isChecked,
    final bool dryRun = false,
  }) async {
    final ProjectData project = await client.getProject(projectId);
    final int id = project.resolveId(key, locale, flavorName: flavor);
    if (dryRun) {
      return OpResult(true, 'DRY RUN: would update "$key" [$locale] (id $id).');
    }
    await client.updateTranslation(
      id,
      value: value,
      isPluralEnabled: isPluralEnabled,
      zeroCase: zeroCase,
      singularCase: singularCase,
      pluralCase: pluralCase,
      pluralParam: pluralParam,
      isPlaceholdersEnabled: isPlaceholdersEnabled,
      placeholders: placeholders,
      isChecked: isChecked,
    );
    return OpResult(true, 'Updated "$key" [$locale].', <String, dynamic>{'key': key, 'locale': locale});
  }

  /// Delete a key. Without [locale] the whole key is removed (all locales + the key
  /// itself). With [locale], only that one locale's translation is deleted.
  Future<OpResult> delete(
    final String key, {
    final String? locale,
    final bool dryRun = false,
  }) async {
    // Whole-key delete: one call, removes the TranslationKey too (no orphaned empty key).
    if (locale == null) {
      if (dryRun) {
        return OpResult(true, 'DRY RUN: would delete the whole key "$key" (all locales).');
      }
      await client.deleteKey(projectId, key);
      return OpResult(
        true,
        'Deleted key "$key" (all locales).',
        <String, dynamic>{'key': key},
      );
    }

    // Single-locale delete: remove just that locale's translation.
    final ProjectData project = await client.getProject(projectId);
    final List<({String locale, int id, bool empty})> targets = project
        .entriesForKey(key, flavorName: flavor)
        .where((final ({bool empty, int id, String locale}) e) => e.locale == locale)
        .toList();

    if (targets.isEmpty) {
      return OpResult(false, 'Nothing to delete for "$key" [$locale].');
    }
    if (dryRun) {
      return OpResult(true, 'DRY RUN: would delete "$key" [$locale].');
    }
    await client.deleteTranslation(targets.first.id);
    return OpResult(true, 'Deleted "$key" [$locale].',
        <String, dynamic>{'key': key, 'locale': locale},);
  }

  /// AI-translate a key's locales. Defaults to the missing ones; pass [all] for every
  /// non-base locale, or [locales] for a specific set.
  Future<OpResult> translate(
    final String key, {
    final List<String>? locales,
    final bool all = false,
    final bool dryRun = false,
  }) async {
    final ProjectData project = await client.getProject(projectId);
    final String? baseCode = project.baseLanguage(flavor)?.code;
    final List<({String locale, int id, bool empty})> entries =
        project.entriesForKey(key, flavorName: flavor);

    Iterable<({String locale, int id, bool empty})> selected =
        entries.where((final ({bool empty, int id, String locale}) e) => e.locale != baseCode);
    if (locales != null && locales.isNotEmpty) {
      selected = selected.where((final ({bool empty, int id, String locale}) e) => locales.contains(e.locale));
    } else if (!all) {
      selected = selected.where((final ({bool empty, int id, String locale}) e) => e.empty); // only-missing default
    }
    final List<int> ids = selected.map((final ({bool empty, int id, String locale}) e) => e.id).toList();
    if (ids.isEmpty) {
      return OpResult(true, 'Nothing to translate for "$key".');
    }
    if (dryRun) {
      return OpResult(true, 'DRY RUN: would translate ${ids.length} locale(s) for "$key".');
    }
    final BatchTranslateResult r = await client.aiBatchTranslate(ids);
    return OpResult(
      r.failedCount == 0,
      'Translated ${r.successCount}/${ids.length} locale(s) for "$key"'
      '${r.failedCount > 0 ? ' (${r.failedCount} failed)' : ''}.',
      <String, dynamic>{
        'translated': r.successCount,
        'failed': r.failed.map((final ({String error, int id}) f) => <String, Object>{'id': f.id, 'error': f.error}).toList(),
      },
    );
  }

  /// Completion status per locale for the selected flavor.
  Future<OpResult> status() async {
    final ProjectData project = await client.getProject(projectId);
    final FlavorData f = project.flavor(flavor);
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    for (final LanguageData l in f.languages) {
      final int total = l.translations.length;
      final int filled = l.translations.where((final TranslationEntry t) => !t.isEmpty).length;
      rows.add(<String, dynamic>{
        'locale': l.code,
        'base': l.isBase,
        'filled': filled,
        'total': total,
        'percent': total == 0 ? 100 : ((filled / total) * 100).round(),
      });
    }
    return OpResult(true, 'Status for "${project.name}" / flavor "${f.name}".',
        <String, dynamic>{'flavor': f.name, 'locales': rows},);
  }
}
