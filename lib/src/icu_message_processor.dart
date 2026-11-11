import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Renders ICU message templates the way `flutter gen-l10n` renders the same
/// ARB entry, so a live update reads exactly like the string it replaces.
///
/// Supports placeholders, `plural` (exact `=N` matches and every CLDR
/// category), `select`, any nesting of those, and the date and number
/// formats gen-l10n accepts in placeholder metadata.
class ICUMessageProcessor {
  final Locale locale;
  final Map<String, String> _localizedStrings;
  final Map<String, dynamic> _messageMetadata;

  /// The locale name handed to intl. gen-l10n passes its own `localeName`,
  /// which [Translator] forwards when it has one.
  final String localeName;

  // Runtime override support
  static Map<String, String>? _runtimeTranslations;
  static Map<String, dynamic>? _runtimeMetadata;

  static final Map<String, List<_Node>> _parsed = <String, List<_Node>>{};
  static const int _parsedCacheLimit = 500;

  // Constants for fallback messages
  static const String keyNotFoundDefault = '{KEY_NOT_FOUND}';
  static const String placeholderValueMissingDefault =
      '{PLACEHOLDER_VALUE_MISSING}';
  static const String typeErrorDefault = '{TYPE_ERROR_FOR_PLACEHOLDER}';
  static const String formattingErrorDefault = '{FORMATTING_ERROR}';

  ICUMessageProcessor(
    this.locale,
    this._localizedStrings,
    this._messageMetadata, {
    final String? localeName,
  }) : localeName = localeName ?? Intl.canonicalizedLocale(locale.toString()) {
    initializeDateFormatting(this.localeName);
  }

  static ICUMessageProcessor? of(final BuildContext context) {
    return Localizations.of<ICUMessageProcessor>(context, ICUMessageProcessor);
  }

  /// Get any string dynamically with full placeholder/plural/select support
  String getString(
    final String key, [
    final Map<String, dynamic>? args,
    final Map<String, dynamic>? placeholders,
  ]) {
    final String template = _getString(key);
    if (args == null || args.isEmpty) return template;
    if (template.endsWith(keyNotFoundDefault)) return template;

    try {
      return format(
        template,
        args,
        placeholders: placeholders ?? getPlaceholderMetadata(key),
      );
    } on FormatException {
      return template;
    }
  }

  /// Renders [template] with [args].
  ///
  /// [placeholders] is the `placeholders` block of the ARB metadata for the
  /// message (`type`, `format`, `optionalParameters`, `isCustomDateFormat`).
  /// Throws a [FormatException] when the template is not valid ICU, or when a
  /// plural or select has no case for the value and no `other`.
  ///
  /// [useEscaping] mirrors `use-escaping: true` in l10n.yaml: a single quote
  /// then quotes literal text (`'{name}'` prints `{name}`) and `''` prints one
  /// quote. Live updates of such a project arrive in that escaped form.
  String format(
    final String template,
    final Map<String, dynamic> args, {
    final Map<String, dynamic>? placeholders,
    final bool useEscaping = false,
  }) {
    return _render(
      _parse(template, useEscaping: useEscaping),
      args,
      placeholders ?? const <String, dynamic>{},
    );
  }

  // ========== RUNTIME UPDATES ==========
  static void updateRuntimeData({
    final Map<String, String>? translations,
    final Map<String, dynamic>? metadata,
  }) {
    _runtimeTranslations = translations;
    _runtimeMetadata = metadata;
  }

  // ========== PRIVATE HELPERS ==========
  String _getString(
    final String key, {
    final Map<String, String>? defaultValues,
  }) {
    // Check runtime cache first
    if (_runtimeTranslations?.containsKey(key) == true) {
      return _runtimeTranslations![key]!;
    }

    final String? defaultValueFromMap = defaultValues?[key];
    final String value = _localizedStrings[key] ??
        (defaultValueFromMap ?? '$key $keyNotFoundDefault');
    return value;
  }

  Map<String, dynamic>? getPlaceholderMetadata(final String messageKey) {
    final String key = '@$messageKey';

    // Check runtime metadata first
    final Object? runtimeEntry = _runtimeMetadata?[key];
    if (runtimeEntry is Map<String, dynamic>) {
      final Object? placeholders = runtimeEntry['placeholders'];
      if (placeholders is Map<String, dynamic>) {
        return placeholders;
      }
    }

    final Object? defaultEntry = _messageMetadata[key];
    if (defaultEntry is Map<String, dynamic>) {
      final Object? placeholders = defaultEntry['placeholders'];
      if (placeholders is Map<String, dynamic>) {
        return placeholders;
      }
    }

    return null;
  }

  /// Substitutes plain `{name}` placeholders, leaving any ICU structure as
  /// text. Kept for callers that only need substitution.
  String substitutePlaceholders(
    final String template,
    final Map<String, dynamic> substitutions,
    final Map<String, dynamic>? placeholderMetadata,
  ) {
    if (template.isEmpty || template.endsWith(keyNotFoundDefault)) {
      return template;
    }
    return template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (final Match m) => _formatArgument(
        m.group(1)!,
        substitutions,
        placeholderMetadata ?? const <String, dynamic>{},
      ),
    );
  }

  String getSelectMessage(
    final String key,
    final String selectValue,
    final Map<String, dynamic> arguments,
  ) {
    final String template = _getString(key);
    final RegExpMatch? selector =
        RegExp(r'\{\s*(\w+)\s*,\s*select\s*,').firstMatch(template);
    final Map<String, dynamic> args = <String, dynamic>{
      ...arguments,
      if (selector != null) selector.group(1)!: selectValue,
    };
    return getString(key, args);
  }

  List<_Node> _parse(final String template, {required final bool useEscaping}) {
    final String cacheKey = useEscaping ? "'$template" : template;
    final List<_Node>? cached = _parsed[cacheKey];
    if (cached != null) return cached;
    final List<_Node> nodes =
        _Parser(template, useEscaping: useEscaping).parse();
    if (_parsed.length >= _parsedCacheLimit) _parsed.clear();
    _parsed[cacheKey] = nodes;
    return nodes;
  }

  String _render(
    final List<_Node> nodes,
    final Map<String, dynamic> args,
    final Map<String, dynamic> placeholders,
  ) {
    final StringBuffer out = StringBuffer();
    for (final _Node node in nodes) {
      switch (node) {
        case _Text(:final String text):
          out.write(text);
        case _Argument(:final String name):
          out.write(_formatArgument(name, args, placeholders));
        case _Plural():
          out.write(
            _render(_pluralCase(node, args), args, placeholders),
          );
        case _Select(:final String name, :final Map<String, List<_Node>> cases):
          final List<_Node>? chosen =
              cases[args[name]?.toString()] ?? cases['other'];
          if (chosen == null) {
            throw FormatException('select "$name" has no "other" case');
          }
          out.write(_render(chosen, args, placeholders));
      }
    }
    return out.toString();
  }

  /// Same choice as gen-l10n: `=0`/`=1`/`=2` are the `zero`/`one`/`two`
  /// arguments of [Intl.pluralLogic], which wins on an exact count before the
  /// locale's plural rules pick `few`, `many` and the rest.
  List<_Node> _pluralCase(
    final _Plural plural,
    final Map<String, dynamic> args,
  ) {
    final Object? raw = args[plural.name];
    final num count =
        raw is num ? raw : num.tryParse(raw?.toString() ?? '') ?? 0;
    final Map<String, List<_Node>> cases = plural.cases;

    for (final MapEntry<String, List<_Node>> entry in cases.entries) {
      if (!entry.key.startsWith('=')) continue;
      final num? exact = num.tryParse(entry.key.substring(1));
      if (exact != null && exact > 2 && exact == count) return entry.value;
    }

    final List<_Node>? other = cases['other'];
    if (other == null) {
      throw FormatException('plural "${plural.name}" has no "other" case');
    }
    return Intl.pluralLogic<List<_Node>>(
      count,
      locale: localeName,
      zero: cases['=0'] ?? cases['zero'],
      one: cases['=1'] ?? cases['one'],
      two: cases['=2'] ?? cases['two'],
      few: cases['few'],
      many: cases['many'],
      other: other,
    );
  }

  String _formatArgument(
    final String name,
    final Map<String, dynamic> args,
    final Map<String, dynamic> placeholders,
  ) {
    if (!args.containsKey(name)) {
      return '{$name $placeholderValueMissingDefault}';
    }
    final Object? value = args[name];
    if (value == null) return placeholderValueMissingDefault;

    final Object? rawMeta = placeholders[name];
    final Map<String, dynamic> meta = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};
    final String? type = meta['type'] as String?;
    final String? format = meta['format'] as String?;

    try {
      if (type == 'DateTime' || (type == null && value is DateTime)) {
        if (value is! DateTime) return typeErrorDefault;
        return _dateFormat(format, meta).format(value);
      }
      if (type == 'int' || type == 'double' || type == 'num') {
        if (value is! num) return typeErrorDefault;
      }
      if (value is num && format != null && format.isNotEmpty) {
        return _numberFormat(format, meta).format(value);
      }
    } on Exception {
      return formattingErrorDefault;
    } on ArgumentError {
      return formattingErrorDefault;
    }
    return value.toString();
  }

  DateFormat _dateFormat(
    final String? format,
    final Map<String, dynamic> meta,
  ) {
    final String pattern = format == null || format.isEmpty ? 'yMd' : format;
    if (_isTrue(meta['isCustomDateFormat'])) {
      return DateFormat(pattern, localeName);
    }
    // gen-l10n joins skeletons with "+": yMd+jm is DateFormat.yMd().add_jm().
    final List<String> parts = pattern.split('+');
    final DateFormat dateFormat = DateFormat(parts.first, localeName);
    for (final String part in parts.skip(1)) {
      dateFormat.addPattern(part);
    }
    return dateFormat;
  }

  NumberFormat _numberFormat(
    final String format,
    final Map<String, dynamic> meta,
  ) {
    final Object? rawOptions = meta['optionalParameters'];
    final Map<String, dynamic> options = <String, dynamic>{
      // Top-level symbol/decimalDigits predate optionalParameters here.
      if (meta['symbol'] != null) 'symbol': meta['symbol'],
      if (meta['decimalDigits'] != null) 'decimalDigits': meta['decimalDigits'],
      if (rawOptions is Map) ...Map<String, dynamic>.from(rawOptions),
    };
    final String? name = options['name'] as String?;
    final String? symbol = options['symbol'] as String?;
    final String? customPattern = options['customPattern'] as String?;
    final int? decimalDigits = options['decimalDigits'] is int
        ? options['decimalDigits'] as int
        : int.tryParse('${options['decimalDigits'] ?? ''}');

    switch (format) {
      case 'compact':
        return NumberFormat.compact(locale: localeName);
      case 'compactCurrency':
        return NumberFormat.compactCurrency(
          locale: localeName,
          name: name,
          symbol: symbol,
          decimalDigits: decimalDigits,
        );
      case 'compactSimpleCurrency':
        return NumberFormat.compactSimpleCurrency(
          locale: localeName,
          name: name,
          decimalDigits: decimalDigits,
        );
      case 'compactLong':
        return NumberFormat.compactLong(locale: localeName);
      case 'currency':
        return NumberFormat.currency(
          locale: localeName,
          name: name,
          symbol: symbol,
          decimalDigits: decimalDigits,
          customPattern: customPattern,
        );
      case 'decimalPattern':
        return NumberFormat.decimalPattern(localeName);
      case 'decimalPatternDigits':
        return NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: decimalDigits,
        );
      case 'decimalPercentPattern':
        return NumberFormat.decimalPercentPattern(
          locale: localeName,
          decimalDigits: decimalDigits,
        );
      case 'percentPattern':
        return NumberFormat.percentPattern(localeName);
      case 'scientificPattern':
        return NumberFormat.scientificPattern(localeName);
      case 'simpleCurrency':
        return NumberFormat.simpleCurrency(
          locale: localeName,
          name: name,
          decimalDigits: decimalDigits,
        );
      default:
        return NumberFormat(format, localeName);
    }
  }

  static bool _isTrue(final Object? value) =>
      value == true || value?.toString().toLowerCase() == 'true';

  // ========== LEGACY METHODS (for backward compatibility) ==========
  String get greeting => _getString(
        'greeting',
        defaultValues: <String, String>{'greeting': 'Hello Default'},
      );

  String welcomeUser(final String userName, {final DateTime? loginDate}) {
    return getString('welcome_user', <String, dynamic>{
      'userName': userName,
      'loginDate': loginDate,
    });
  }

  String itemCount(
    final int count,
    final String userName, {
    final double? totalCost,
  }) {
    return getString('item_count', <String, dynamic>{
      'count': count,
      'userName': userName,
      'totalCost': totalCost,
    });
  }

  static Future<ICUMessageProcessor> load(
    final Locale locale,
    final Map<String, String> translations,
    final Map<String, dynamic> metadata,
  ) async {
    return ICUMessageProcessor(locale, translations, metadata);
  }
}

sealed class _Node {
  const _Node();
}

class _Text extends _Node {
  const _Text(this.text);
  final String text;
}

class _Argument extends _Node {
  const _Argument(this.name);
  final String name;
}

class _Plural extends _Node {
  const _Plural(this.name, this.cases);
  final String name;
  final Map<String, List<_Node>> cases;
}

class _Select extends _Node {
  const _Select(this.name, this.cases);
  final String name;
  final Map<String, List<_Node>> cases;
}

/// Parses the ICU subset gen-l10n accepts. With `use-escaping: false` (its
/// default) quotes are literal text; with it on, they quote literal text. A
/// brace that does not open an argument is kept as text either way.
class _Parser {
  _Parser(this._source, {required this.useEscaping});

  final String _source;
  final bool useEscaping;
  int _pos = 0;

  static final RegExp _identifierStart = RegExp(r'[A-Za-z_]');
  static final RegExp _identifierPart = RegExp(r'\w');

  List<_Node> parse() {
    final List<_Node> nodes = _message(nested: false);
    if (_pos < _source.length) {
      throw FormatException('Unexpected "}"', _source, _pos);
    }
    return nodes;
  }

  List<_Node> _message({required final bool nested}) {
    final List<_Node> nodes = <_Node>[];
    final StringBuffer text = StringBuffer();

    void flush() {
      if (text.isEmpty) return;
      nodes.add(_Text(text.toString()));
      text.clear();
    }

    while (_pos < _source.length) {
      final String char = _source[_pos];
      if (char == '}') {
        if (nested) break;
        text.write(char);
        _pos++;
      } else if (useEscaping && char == "'") {
        if (_pos + 1 < _source.length && _source[_pos + 1] == "'") {
          text.write("'");
          _pos += 2;
          continue;
        }
        final int close = _source.indexOf("'", _pos + 1);
        if (close == -1) {
          throw FormatException('Unpaired quote', _source, _pos);
        }
        text.write(_source.substring(_pos + 1, close));
        _pos = close + 1;
      } else if (char == '{') {
        final _Node? argument = _argument();
        if (argument == null) {
          text.write(char);
          _pos++;
        } else {
          flush();
          nodes.add(argument);
        }
      } else {
        text.write(char);
        _pos++;
      }
    }
    flush();
    return nodes;
  }

  /// Parses an argument at `{`, or returns null with the position untouched
  /// when the brace does not start one.
  _Node? _argument() {
    final int start = _pos;
    _pos++;
    _spaces();
    final String? name = _identifier();
    if (name == null) {
      _pos = start;
      return null;
    }
    _spaces();
    if (_peek('}')) {
      _pos++;
      return _Argument(name);
    }
    if (!_peek(',')) {
      _pos = start;
      return null;
    }
    _pos++;
    _spaces();
    final String? kind = _identifier();
    _spaces();
    if ((kind != 'plural' && kind != 'select') || !_peek(',')) {
      _pos = start;
      return null;
    }
    _pos++;

    final Map<String, List<_Node>> cases = <String, List<_Node>>{};
    while (true) {
      _spaces();
      if (_pos >= _source.length) {
        throw FormatException('Unclosed $kind', _source, start);
      }
      if (_peek('}')) {
        _pos++;
        break;
      }
      final String? key = _caseKey();
      if (key == null) {
        throw FormatException('Expected a $kind case', _source, _pos);
      }
      _spaces();
      if (!_peek('{')) {
        throw FormatException('Expected "{" after "$key"', _source, _pos);
      }
      _pos++;
      cases[key] = _message(nested: true);
      if (!_peek('}')) {
        throw FormatException('Unclosed case "$key"', _source, _pos);
      }
      _pos++;
    }
    return kind == 'plural' ? _Plural(name, cases) : _Select(name, cases);
  }

  String? _caseKey() {
    if (_peek('=')) {
      final int start = _pos;
      _pos++;
      while (_pos < _source.length &&
          RegExp(r'[0-9.\-]').hasMatch(_source[_pos])) {
        _pos++;
      }
      return _pos - start > 1 ? _source.substring(start, _pos) : null;
    }
    return _identifier();
  }

  String? _identifier() {
    if (_pos >= _source.length || !_identifierStart.hasMatch(_source[_pos])) {
      return null;
    }
    final int start = _pos;
    while (_pos < _source.length && _identifierPart.hasMatch(_source[_pos])) {
      _pos++;
    }
    return _source.substring(start, _pos);
  }

  void _spaces() {
    while (_pos < _source.length && _source[_pos].trim().isEmpty) {
      _pos++;
    }
  }

  bool _peek(final String char) =>
      _pos < _source.length && _source[_pos] == char;
}
