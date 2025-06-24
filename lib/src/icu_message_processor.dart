import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class ICUMessageProcessor {
  final Locale locale;
  final Map<String, String> _localizedStrings;
  final Map<String, dynamic> _messageMetadata;

  // Runtime override support
  static Map<String, String>? _runtimeTranslations;
  static Map<String, dynamic>? _runtimeMetadata;

  // Constants for fallback messages
  static const String keyNotFoundDefault = '{KEY_NOT_FOUND}';
  static const String placeholderValueMissingDefault =
      '{PLACEHOLDER_VALUE_MISSING}';
  static const String typeErrorDefault = '{TYPE_ERROR_FOR_PLACEHOLDER}';
  static const String formattingErrorDefault = '{FORMATTING_ERROR}';

  ICUMessageProcessor(
    this.locale,
    this._localizedStrings,
    this._messageMetadata,
  ) {
    initializeDateFormatting(locale.toString());
  }

  static ICUMessageProcessor? of(final BuildContext context) {
    return Localizations.of<ICUMessageProcessor>(context, ICUMessageProcessor);
  }

  // ========== DYNAMIC STRING LOOKUP - THE MAGIC METHOD ==========
  /// Get any string dynamically with full placeholder/plural/select support
  String getString(final String key, [final Map<String, dynamic>? args]) {
    // Simple string case
    if (args == null || args.isEmpty) {
      return _getString(key);
    }

    // Check if it's a plural message (contains 'plural' keyword)
    final String template = _getString(key);
    if (template.contains(', plural,')) {
      // Extract count from args
      final int count = args['count'] ?? 0;
      return _handlePluralMessage(key, count, args);
    }

    // Check if it's a select message (contains 'select' keyword)
    if (template.contains(', select,')) {
      // Find the selector variable
      final String? selectorKey = _findSelectorVariable(template);
      if (selectorKey != null && args.containsKey(selectorKey)) {
        return getSelectMessage(key, args[selectorKey].toString(), args);
      }
    }

    // Regular placeholder substitution
    return substitutePlaceholders(template, args, getPlaceholderMetadata(key));
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
    // Check runtime metadata first
    if (_runtimeMetadata?.containsKey('@$messageKey') == true) {
      return _runtimeMetadata!['@$messageKey']?['placeholders'];
    }
    return _messageMetadata['@$messageKey']?['placeholders'];
  }

  String? _findSelectorVariable(final String template) {
    final RegExpMatch? match =
        RegExp(r'\{(\w+),\s*select,').firstMatch(template);
    return match?.group(1);
  }

  String _handlePluralMessage(
    final String key,
    final dynamic countValue,
    final Map<String, dynamic> args,
  ) {
    final String template = _getString(key);
    final Map<String, dynamic> metadata =
        getPlaceholderMetadata(key) ?? <String, dynamic>{};

    // Find the placeholder variable used for plural
    final RegExpMatch? pluralVarMatch =
        RegExp(r'\{(\w+),\s*plural,').firstMatch(template);
    final String pluralVar = pluralVarMatch?.group(1) ?? 'count';
    final num count = args[pluralVar] is num ? args[pluralVar] : 0;

    // Extract ICU cases
    String? zeroCase = _extractIcuCaseValue(template, '=0');
    if (zeroCase.isEmpty) zeroCase = _extractIcuCaseValue(template, 'zero');

    String? oneCase = _extractIcuCaseValue(template, '=1');
    if (oneCase.isEmpty) oneCase = _extractIcuCaseValue(template, 'one');

    String? twoCase = _extractIcuCaseValue(template, '=2');
    if (twoCase.isEmpty) twoCase = _extractIcuCaseValue(template, 'two');

    final String? fewCase = _extractIcuCaseValue(template, 'few');
    final String? manyCase = _extractIcuCaseValue(template, 'many');
    final String arbOtherCase = _extractIcuCaseValue(template, 'other');

    final String fallbackOther = '{$pluralVar} items (fallback)';

    final String selectedCase = Intl.plural(
      count,
      zero: zeroCase.isNotEmpty == true ? zeroCase : null,
      one: oneCase.isNotEmpty == true ? oneCase : null,
      two: twoCase.isNotEmpty == true ? twoCase : null,
      few: fewCase?.isNotEmpty == true ? fewCase : null,
      many: manyCase?.isNotEmpty == true ? manyCase : null,
      other: arbOtherCase.isNotEmpty ? arbOtherCase : fallbackOther,
      name: key,
      locale: locale.toString(),
    );

    // Add the plural variable to args for placeholder substitution, if missing
    final Map<String, dynamic> substArgs = Map<String, dynamic>.from(args);
    if (!substArgs.containsKey(pluralVar)) {
      substArgs[pluralVar] = count;
    }

    return substitutePlaceholders(selectedCase, substArgs, metadata);
  }

  String substitutePlaceholders(
    final String template,
    final Map<String, dynamic> substitutions,
    final Map<String, dynamic>? placeholderMetadata,
  ) {
    String result = template;
    if (template.isEmpty || template.endsWith(keyNotFoundDefault)) {
      return template;
    }

    final RegExp exp = RegExp(r'\{(\w+)\}');
    final Iterable<Match> matches = exp.allMatches(template);

    for (Match m in matches) {
      final String placeholderName = m.group(1)!;
      final String fullPlaceholder = m.group(0)!;

      if (substitutions.containsKey(placeholderName)) {
        final dynamic value = substitutions[placeholderName];
        String stringValue;
        final Map<String, dynamic>? meta =
            placeholderMetadata?[placeholderName];

        if (value == null) {
          stringValue = placeholderValueMissingDefault;
        } else if (meta != null) {
          final String type = meta['type'] ?? 'String';
          final String? format = meta['format'];
          final String? symbol = meta['symbol'];

          switch (type) {
            case 'DateTime':
              if (value is DateTime) {
                try {
                  stringValue = DateFormat(
                    format ?? 'yMd',
                    locale.toString(),
                  ).format(value);
                } on Exception catch (_) {
                  stringValue = formattingErrorDefault;
                }
              } else {
                stringValue = typeErrorDefault;
              }
              break;
            case 'int':
            case 'double':
            case 'num':
              if (value is num) {
                try {
                  if (format == 'currency') {
                    stringValue = NumberFormat.currency(
                      locale: locale.toString(),
                      symbol: symbol,
                    ).format(value);
                  } else if (format == 'decimalPattern' ||
                      format == 'decimalPercentPattern') {
                    stringValue = NumberFormat.decimalPattern(
                      locale.toString(),
                    ).format(value);
                  } else if (format != null && format.isNotEmpty) {
                    stringValue = NumberFormat(
                      format,
                      locale.toString(),
                    ).format(value);
                  } else {
                    stringValue = value.toString();
                  }
                } catch (e) {
                  stringValue = formattingErrorDefault;
                }
              } else {
                stringValue = typeErrorDefault;
              }
              break;
            case 'String':
            default:
              stringValue = value.toString();
              break;
          }
        } else {
          stringValue = value.toString();
        }
        result = result.replaceAll(fullPlaceholder, stringValue);
      } else {
        result = result.replaceAll(
          fullPlaceholder,
          '{$placeholderName $placeholderValueMissingDefault}',
        );
      }
    }
    return result;
  }

  String _extractIcuCaseValue(
    final String fullIcuString,
    final String caseKey,
  ) {
    final RegExp regex = RegExp(
      RegExp.escape(caseKey) + r'\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}',
    );
    final RegExpMatch? match = regex.firstMatch(fullIcuString);
    return match?.group(1) ?? '';
  }

  String getSelectMessage(
    final String key,
    final String selectValue,
    final Map<String, dynamic> arguments,
  ) {
    final String icuStringTemplate = _getString(key);
    final Map<String, dynamic> currentPlaceholdersMetadata =
        getPlaceholderMetadata(key) ?? <String, dynamic>{};

    final RegExp caseFinder = RegExp(
      r'(\w+)\s*(\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\})',
    );
    final Map<String, String> dynamicCases = <String, String>{};

    String? selectorVariable;
    final RegExpMatch? selectorMatch = RegExp(
      r'\{(\w+),\s*select,',
    ).firstMatch(icuStringTemplate);
    if (selectorMatch != null) {
      selectorVariable = selectorMatch.group(1);
    }

    for (final RegExpMatch match in caseFinder.allMatches(icuStringTemplate)) {
      final String caseKey = match.group(1)!;
      final String caseValue = match.group(3) ?? '';
      if (caseKey != selectorVariable) {
        dynamicCases[caseKey] = caseValue;
      }
    }

    if (!dynamicCases.containsKey('other') ||
        (dynamicCases['other']?.isEmpty ?? true)) {
      dynamicCases['other'] = 'Default other case';
    }

    final String selectedCaseTemplate = Intl.select(
      selectValue,
      dynamicCases,
      name: key.replaceAll('@', ''),
      locale: locale.toString(),
    );

    return substitutePlaceholders(
      selectedCaseTemplate,
      arguments,
      currentPlaceholdersMetadata,
    );
  }

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
