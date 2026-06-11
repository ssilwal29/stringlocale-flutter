import 'dart:convert';

import 'package:http/http.dart' as http;

import 'file_web.dart' if (dart.library.io) 'file_io.dart';

import 'text.dart';
import 'formatters.dart';
import 'plural_rule.dart';
import 'llm.dart';

/// Runtime renderer. Loads compiled locale JSON (with overrides merged) and
/// renders [Message] objects.
///
/// `translatable` and `userAdapted` params call the LLM on first use and are
/// cached in-memory for the lifetime of this renderer.
class Renderer {
  /// Create a renderer backed by generated locale files, in-memory data, or both.
  Renderer({
    this.localeDir = 'locales',
    this.model = defaultModel,
    this.apiKey,
    this.useDigitConversion = true,
    Map<String, Map<String, dynamic>>? localeData,
    Map<String, Map<String, dynamic>>? overrides,
    http.Client? client,
  }) : _client = client {
    if (overrides != null) {
      overrides.forEach((code, data) => _overrides[code] = data);
    }
    if (localeData != null) {
      localeData.forEach(setLocale);
    }
  }

  /// Directory containing generated locale JSON files.
  final String localeDir;

  /// OpenRouter model used for runtime value translation/adaptation.
  final String model;

  /// OpenRouter API key. If omitted, `OPENROUTER_API_KEY` is read lazily.
  final String? apiKey;

  /// Whether ASCII digits in formatted values should be converted per locale.
  final bool useDigitConversion;
  final http.Client? _client;

  // locale code → merged {key: entry}
  final Map<String, Map<String, dynamic>> _localeCache = {};
  // locale code → override {key: entry}
  final Map<String, Map<String, dynamic>> _overrides = {};
  // cacheKey → translated value
  final Map<String, String> _valueCache = {};

  /// Number of cached runtime translated/adapted values.
  int get valueCacheSize => _valueCache.length;

  /// Clear cached runtime translated/adapted values.
  void clearValueCache() => _valueCache.clear();

  /// Clear loaded locale JSON data. Manually set overrides are retained.
  void clearLocaleCache() => _localeCache.clear();

  /// Register compiled locale data directly (with overrides merged on top).
  void setLocale(String localeCode, Map<String, dynamic> data) {
    final override = _overrides[localeCode];
    if (override != null) {
      _localeCache[localeCode] = {...data, ...override};
    } else {
      _localeCache[localeCode] = Map.of(data);
    }
  }

  /// Register manual overrides for a locale — they always win at render time.
  void setOverrides(String localeCode, Map<String, dynamic> data) {
    _overrides[localeCode] = data;
    final base = _localeCache[localeCode];
    if (base != null) {
      _localeCache[localeCode] = {...base, ...data};
    }
  }

  /// Load a locale JSON file from disk (Dart VM / Flutter non-web), merging
  /// `localeDir/overrides/<code>.json` on top.
  Future<void> loadLocale(String localeCode) async {
    if (_localeCache.containsKey(localeCode)) return;

    Map<String, dynamic> data = {};
    final raw = await readFileIfExists('$localeDir/$localeCode.json');
    if (raw != null) {
      data = jsonDecode(raw) as Map<String, dynamic>;
    }

    final overrideRaw =
        await readFileIfExists('$localeDir/overrides/$localeCode.json');
    if (overrideRaw != null) {
      final overrideData = jsonDecode(overrideRaw) as Map<String, dynamic>;
      _overrides[localeCode] = overrideData;
      data = {...data, ...overrideData};
    }

    _localeCache[localeCode] = data;
  }

  Map<String, dynamic> _getLocale(String localeCode) =>
      _localeCache[localeCode] ?? const {};

  dynamic _getEntry(String localeCode, String key) =>
      _getLocale(localeCode)[key];

  bool _isPluralEntry(dynamic entry) =>
      entry is Map && entry.containsKey('singular');

  Future<String> _translateValue(
    String value,
    String localeCode,
    String languageName,
    String? context,
  ) async {
    final cacheKey = 'tr:$value::$localeCode::${context ?? ''}';
    final cached = _valueCache[cacheKey];
    if (cached != null) return cached;

    final translated = await translateValue(
      value,
      localeCode,
      languageName,
      context: context,
      model: model,
      apiKey: apiKey,
      client: _client,
    );
    _valueCache[cacheKey] = translated;
    return translated;
  }

  Future<String> _adaptValue(
    String value,
    String localeCode,
    String languageName,
    String? context,
  ) async {
    final hash = value.hashCode.toRadixString(16);
    final cacheKey = 'adapt:$hash::$localeCode::${context ?? ''}';
    final cached = _valueCache[cacheKey];
    if (cached != null) return cached;

    final adapted = await adaptFreeText(
      value,
      localeCode,
      languageName,
      context: context,
      model: model,
      apiKey: apiKey,
      client: _client,
    );
    _valueCache[cacheKey] = adapted;
    return adapted;
  }

  /// Render [text] in the given locale.
  ///
  /// [languageName] is required only when the text has `translatable` or
  /// `userAdapted` params and [localeCode] is not 'en'.
  Future<String> render(
    Message text,
    String localeCode, {
    String? languageName,
    Map<String, Object?> args = const {},
  }) async {
    final isPlural = text.isPlural;

    // Resolve template
    String? template;
    Map<String, dynamic>? pluralEntry;

    if (localeCode == 'en') {
      template = isPlural ? text.source.split(pluralSep)[0] : text.source;
    } else {
      final entry = _getEntry(localeCode, text.key);
      if (entry == null) {
        // Fallback to English source
        template = isPlural ? text.source.split(pluralSep)[1] : text.source;
      } else if (_isPluralEntry(entry)) {
        pluralEntry = (entry as Map).cast<String, dynamic>();
        template = pluralEntry['plural'] as String;
      } else if (entry is Map && entry.containsKey('text')) {
        template = entry['text'] as String;
      } else {
        template = entry.toString();
      }
    }

    if (!isPlural && text.params.isEmpty) {
      return template;
    }

    // Resolve params
    final resolved = <String, String>{};
    num? countValue;
    String pluralCountParam = 'count';

    for (final param in text.params) {
      if (!args.containsKey(param.name)) {
        throw ArgumentError(
            'Missing param "${param.name}" for Text "${text.key}"');
      }
      final raw = args[param.name];

      switch (param.kind) {
        case ParamKind.numberPlural:
          pluralCountParam = param.name;
          countValue = raw is num ? raw : num.parse(raw.toString());
          resolved[param.name] = useDigitConversion
              ? formatNumber(countValue, localeCode)
              : countValue.toString();
          break;

        case ParamKind.number:
          resolved[param.name] = useDigitConversion
              ? formatNumber(raw!, localeCode)
              : raw.toString();
          break;

        case ParamKind.date:
          final formatted = formatDateValue(raw!, localeCode, param.fmt);
          resolved[param.name] = useDigitConversion
              ? formatNumber(formatted, localeCode)
              : formatted;
          break;

        case ParamKind.currency:
          final formatted =
              formatCurrencyValue(raw!, localeCode, param.currency);
          resolved[param.name] = useDigitConversion
              ? formatNumber(formatted, localeCode)
              : formatted;
          break;

        case ParamKind.relative:
          final formatted = formatRelativeValue(raw!, localeCode);
          resolved[param.name] = useDigitConversion
              ? formatNumber(formatted, localeCode)
              : formatted;
          break;

        case ParamKind.translatable:
          if (localeCode == 'en') {
            resolved[param.name] = raw.toString();
          } else {
            if (languageName == null) {
              throw ArgumentError(
                'languageName is required for translatable param '
                '"${param.name}" in Text "${text.key}"',
              );
            }
            resolved[param.name] = await _translateValue(
              raw.toString(),
              localeCode,
              languageName,
              param.context,
            );
          }
          break;

        case ParamKind.userAdapted:
          if (localeCode == 'en') {
            resolved[param.name] = raw.toString();
          } else {
            if (languageName == null) {
              throw ArgumentError(
                'languageName is required for userAdapted param '
                '"${param.name}" in Text "${text.key}"',
              );
            }
            resolved[param.name] = await _adaptValue(
              raw.toString(),
              localeCode,
              languageName,
              param.context,
            );
          }
          break;

        case ParamKind.literal:
        case ParamKind.user:
          resolved[param.name] = raw.toString();
          break;
      }
    }

    // Resolve plural form now that we know countValue
    if (isPlural) {
      if (countValue == null) {
        throw ArgumentError(
            'Text "${text.key}" is plural but no numberPlural param found');
      }
      if (localeCode == 'en') {
        final parts = text.source.split(pluralSep);
        template = countValue < 2 ? parts[0] : parts[1];
      } else if (pluralEntry != null) {
        final rule = pluralEntry['rule'] as String? ?? '$pluralCountParam < 2';
        final useSingular =
            PluralRuleEvaluator(pluralCountParam).eval(rule, countValue);
        template = useSingular
            ? pluralEntry['singular'] as String
            : pluralEntry['plural'] as String;
      }
    }

    // Substitute placeholders
    return template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => resolved[m.group(1)] ?? '{${m.group(1)}}',
    );
  }
}
