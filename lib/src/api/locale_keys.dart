import 'package:flutter/widgets.dart';

/// Cache keys to try for a locale, most specific first.
///
/// Live-update overrides are stored under the locale code the project holds,
/// which is BCP-47: `pt`, `pt-BR`, `zh-Hant`, `es-419`. A device, meanwhile,
/// reports a full [Locale], and the ARB tooling spells the same identity with
/// an underscore (`app_pt_BR.arb`, `@@locale: pt_BR`). Looking up only
/// `locale.languageCode` — which is what this used to do — meant a Brazilian
/// device read the European Portuguese overrides, and a project holding only
/// `pt-BR` got no overrides at all while the dashboard showed them published.
///
/// Both separators are emitted for each candidate because the cache can be
/// written from either source, and the fallback chain ends at the bare
/// language so a variant device still receives base-language overrides.
List<String> localeCacheKeys(final Locale locale) {
  final String language = locale.languageCode.toLowerCase();
  final String? script = locale.scriptCode;
  final String? region = locale.countryCode;

  final List<String> tags = <String>[];
  void add(final String tag) {
    if (!tags.contains(tag)) tags.add(tag);
  }

  final String? normalisedScript = script == null || script.isEmpty
      ? null
      : script[0].toUpperCase() + script.substring(1).toLowerCase();
  final String? normalisedRegion = region == null || region.isEmpty
      ? null
      : (int.tryParse(region) != null ? region : region.toUpperCase());

  if (normalisedScript != null && normalisedRegion != null) {
    add('$language-$normalisedScript-$normalisedRegion');
  }
  if (normalisedScript != null) add('$language-$normalisedScript');
  if (normalisedRegion != null) add('$language-$normalisedRegion');
  add(language);

  return <String>[
    for (final String tag in tags) ...<String>[
      tag,
      if (tag.contains('-')) tag.replaceAll('-', '_'),
    ],
  ];
}
