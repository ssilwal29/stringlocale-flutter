/// Runtime Bundle — loads compiled bundles and resolves strings offline.
library;

import 'dart:convert';

import 'plural_rules.dart';
import 'formatters.dart';
import 'user_adapted_openrouter.dart'
    if (dart.library.io) 'user_adapted_openrouter_io.dart' as openrouter;

const String pluralToken = '__plural__';

final RegExp _placeholderRe = RegExp(r'\{(\w+)\}');

/// adapter(value, locale, context) -> reformatted string (userAdapted hatch).
typedef Adapter = String Function(String value, String locale, String? context);
typedef AsyncAdapter = Future<String> Function(
    String value, String locale, String? context);

enum UserAdaptedMode {
  cached,
  realtime,
}

class MissingRequiredAxis implements Exception {
  MissingRequiredAxis(this.message);
  final String message;
  @override
  String toString() => 'MissingRequiredAxis: $message';
}

class StringNotFound implements Exception {
  StringNotFound(this.id);
  final String id;
  @override
  String toString() => 'StringNotFound: $id';
}

/// A function that reads a file's contents, injected so the runtime stays
/// platform-agnostic (dart:io on VM, asset bundle on Flutter, etc.).
typedef FileReader = String? Function(String path);

/// A resolved locale bundle.
///
/// Load one with [Bundle.fromJsonString] or [Bundle.fromDir], then call
/// [resolve] (sync) or [resolveAsync] (async, needed for `userAdapted` params)
/// to render strings for a given locale and set of arguments.
///
/// Optionally supply a custom [adapter] / [asyncAdapter] to override the
/// default OpenRouter-backed `userAdapted` behaviour.
class Bundle {
  /// Create a bundle from a pre-decoded JSON map (combined or per-locale format).
  Bundle(
    Map<String, dynamic> data, {
    this.adapter,
    this.asyncAdapter,
    this.userAdaptedMode = UserAdaptedMode.cached,
    Map<String, List<String>>? fallbacks,
  }) : _fallbacks = fallbacks ?? {} {
    _merge(data);
  }

  final Adapter? adapter;
  final AsyncAdapter? asyncAdapter;
  final UserAdaptedMode userAdaptedMode;
  final Map<String, List<String>> _fallbacks;
  Adapter? _defaultOpenRouterAdapter;
  AsyncAdapter? _defaultAsyncOpenRouterAdapter;
  bool _defaultOpenRouterInitialized = false;
  bool _defaultAsyncOpenRouterInitialized = false;

  // locale -> {id: spec}
  final Map<String, Map<String, dynamic>> _byLocale = {};
  String _sourceLocale = 'en';
  final List<String> locales = [];
  final Map<String, String> _adaptCache = {};

  // For lazy ensureLocale (set by fromDir-style loaders).
  String? _sourceDir;
  Map<String, dynamic>? _manifest;
  FileReader? _reader;

  void _merge(Map<String, dynamic> data) {
    _sourceLocale = (data['source_locale'] as String?) ?? _sourceLocale;
    if (data.containsKey('locale')) {
      // Per-locale file.
      final loc = data['locale'] as String;
      _byLocale[loc] = Map<String, dynamic>.from(data['strings'] as Map? ?? {});
      if (!locales.contains(loc)) locales.add(loc);
    } else {
      // Combined file.
      final locs = (data['locales'] as List?)?.cast<String>() ?? [];
      for (final loc in locs) {
        _byLocale.putIfAbsent(loc, () => {});
        if (!locales.contains(loc)) locales.add(loc);
      }
      final strings = data['strings'] as Map? ?? {};
      strings.forEach((sid, spec) {
        final specMap = spec as Map;
        final cells = specMap['cells'] as Map? ?? {};
        final meta = <String, dynamic>{
          for (final e in specMap.entries)
            if (e.key != 'cells') e.key: e.value
        };
        cells.forEach((loc, cell) {
          final cellMap = cell as Map;
          final merged = Map<String, dynamic>.from(meta);
          merged['templates'] = cellMap['templates'] ?? {};
          merged['enum_values'] =
              cellMap['enums'] ?? cellMap['enum_values'] ?? {};
          _byLocale.putIfAbsent(loc as String, () => {})[sid as String] =
              merged;
          if (!locales.contains(loc)) locales.add(loc);
        });
      });
    }
  }

  /// Merge another bundle's data (per-locale or combined) into this one.
  /// Useful for assembling a multi-locale bundle in memory.
  void merge(Map<String, dynamic> data) => _merge(data);

  /// Alias used by tests.
  void mergeForTest(Map<String, dynamic> data) => _merge(data);

  // ── construction ────────────────────────────────────────────────────────────

  factory Bundle.fromJsonString(String jsonStr,
          {Adapter? adapter,
          AsyncAdapter? asyncAdapter,
          UserAdaptedMode userAdaptedMode = UserAdaptedMode.cached,
          Map<String, List<String>>? fallbacks}) =>
      Bundle(jsonDecode(jsonStr) as Map<String, dynamic>,
          adapter: adapter,
          asyncAdapter: asyncAdapter,
          userAdaptedMode: userAdaptedMode,
          fallbacks: fallbacks);

  /// Load per-locale files from a directory via its manifest.json.
  /// [reader] reads a file path to its string contents (inject dart:io or assets).
  factory Bundle.fromDir(
    String directory,
    FileReader reader, {
    List<String>? locales,
    Adapter? adapter,
    AsyncAdapter? asyncAdapter,
    UserAdaptedMode userAdaptedMode = UserAdaptedMode.cached,
    Map<String, List<String>>? fallbacks,
    bool includeFallbacks = true,
  }) {
    final manifestStr = reader('$directory/manifest.json');
    if (manifestStr == null) {
      throw StateError('No manifest.json in $directory');
    }
    final manifest = jsonDecode(manifestStr) as Map<String, dynamic>;
    final files = manifest['files'] as Map? ?? {};
    final source = (manifest['source_locale'] as String?) ?? 'en';

    final want = <String>[
      ...(locales ?? (manifest['locales'] as List).cast<String>())
    ];

    if (locales != null && includeFallbacks) {
      for (final loc in locales) {
        final lang = loc.replaceAll('_', '-').split('-')[0];
        for (final cand in [...?fallbacks?[loc], lang, source]) {
          if (files.containsKey(cand) && !want.contains(cand)) want.add(cand);
        }
      }
    }

    Bundle? bundle;
    for (final loc in want) {
      final entry = files[loc] as Map?;
      if (entry == null) continue;
      final content = reader('$directory/${entry['path']}');
      if (content == null) continue;
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (bundle == null) {
        bundle = Bundle(
          data,
          adapter: adapter,
          asyncAdapter: asyncAdapter,
          userAdaptedMode: userAdaptedMode,
          fallbacks: fallbacks,
        );
      } else {
        bundle._merge(data);
      }
    }
    if (bundle == null) {
      throw StateError('No matching locale files in $directory');
    }
    bundle._sourceDir = directory;
    bundle._manifest = manifest;
    bundle._reader = reader;
    return bundle;
  }

  // ── fallback chain ──────────────────────────────────────────────────────────

  List<String> _fallbackChain(String locale) {
    final chain = <String>[locale];
    for (final f in _fallbacks[locale] ?? const []) {
      chain.add(f);
    }
    final lang = locale.replaceAll('_', '-').split('-')[0];
    if (lang != locale) chain.add(lang);
    for (final loc in _byLocale.keys) {
      if (loc.split('-')[0] == lang && !chain.contains(loc)) chain.add(loc);
    }
    chain.add(_sourceLocale);
    chain.add(_sourceLocale.replaceAll('_', '-').split('-')[0]);

    final seen = <String>{};
    final out = <String>[];
    for (final c in chain) {
      if (seen.add(c)) out.add(c);
    }
    return out;
  }

  Map<String, dynamic>? _spec(String locale, String id) {
    for (final loc in _fallbackChain(locale)) {
      final strings = _byLocale[loc];
      if (strings != null && strings.containsKey(id)) {
        return strings[id] as Map<String, dynamic>;
      }
    }
    return null;
  }

  bool ensureLocale(String locale) {
    if (_byLocale.containsKey(locale)) return true;
    if (_sourceDir == null || _manifest == null || _reader == null) {
      return false;
    }
    final files = _manifest!['files'] as Map? ?? {};
    final source = (_manifest!['source_locale'] as String?) ?? 'en';
    final lang = locale.replaceAll('_', '-').split('-')[0];
    var loaded = false;
    for (final cand in [locale, ...?_fallbacks[locale], lang, source]) {
      if (_byLocale.containsKey(cand)) continue;
      final entry = files[cand] as Map?;
      if (entry == null) continue;
      final content = _reader!('$_sourceDir/${entry['path']}');
      if (content == null) continue;
      _merge(jsonDecode(content) as Map<String, dynamic>);
      if (cand == locale) loaded = true;
    }
    return loaded || _byLocale.containsKey(locale);
  }

  /// Returns true if [id] is present in any loaded locale.
  bool has(String id) => _byLocale.values.any((s) => s.containsKey(id));

  /// All string IDs loaded across all locales.
  List<String> ids() {
    final seen = <String>[];
    for (final strings in _byLocale.values) {
      for (final sid in strings.keys) {
        if (!seen.contains(sid)) seen.add(sid);
      }
    }
    return seen;
  }

  /// Resolve [id] for [locale] synchronously.
  ///
  /// For strings with `userAdapted` params, the sync adapter is used (or the
  /// raw value if none is set). Use [resolveAsync] when you need the
  /// OpenRouter-backed async adapter.
  String resolve(String locale, String id,
      [Map<String, Object?> args = const {}]) {
    final spec = _spec(locale, id);
    if (spec == null) throw StringNotFound(id);
    return _resolveSpec(locale, id, spec, args);
  }

  /// Resolve [id] for [locale] asynchronously.
  ///
  /// Required for strings that contain `userAdapted` params: the async adapter
  /// (e.g. the default OpenRouter adapter) is awaited for each such param.
  /// Results are cached by `(value, locale, context)` unless
  /// [userAdaptedMode] is [UserAdaptedMode.realtime].
  Future<String> resolveAsync(String locale, String id,
      [Map<String, Object?> args = const {}]) async {
    final spec = _spec(locale, id);
    if (spec == null) throw StringNotFound(id);
    return _resolveSpecAsync(locale, id, spec, args);
  }

  // ── resolution ──────────────────────────────────────────────────────────────

  String _resolveSpec(String locale, String sid, Map<String, dynamic> spec,
      Map<String, Object?> args) {
    final axisOrder = (spec['axis_order'] as List?)?.cast<String>() ?? const [];
    final freeAxes = (spec['free_axes'] as Map?) ?? const {};
    final required =
        ((spec['required'] as List?) ?? const []).cast<String>().toSet();
    final pluralParam = spec['plural_param'] as String?;
    final inlined =
        ((spec['inlined_enums'] as List?) ?? const []).cast<String>();

    final tokens = <String>[];
    for (final axis in axisOrder) {
      if (axis == pluralToken) {
        if (pluralParam == null || !args.containsKey(pluralParam)) {
          throw MissingRequiredAxis('$sid: plural param required');
        }
        tokens.add(pluralCategory(locale, args[pluralParam]));
      } else if (inlined.contains(axis)) {
        if (!args.containsKey(axis)) {
          throw MissingRequiredAxis("$sid: enum '$axis' required");
        }
        tokens.add(args[axis].toString());
      } else {
        if (args.containsKey(axis)) {
          tokens.add(args[axis].toString());
        } else if (required.contains(axis)) {
          throw MissingRequiredAxis("$sid: axis '$axis' required");
        } else {
          final vals = (freeAxes[axis] as List?)?.cast<String>() ?? const [];
          tokens.add(vals.isNotEmpty ? vals[0] : '');
        }
      }
    }

    final templates = (spec['templates'] as Map?) ?? const {};
    var template = templates[tokens.join('|')] as String?;
    template ??= templates.isNotEmpty
        ? templates.values.first as String
        : (spec['text'] as String? ?? '');

    final enumValues = (spec['enum_values'] as Map?) ?? const {};
    return _substitute(template, locale, spec, args, enumValues);
  }

  Future<String> _resolveSpecAsync(String locale, String sid,
      Map<String, dynamic> spec, Map<String, Object?> args) async {
    final axisOrder = (spec['axis_order'] as List?)?.cast<String>() ?? const [];
    final freeAxes = (spec['free_axes'] as Map?) ?? const {};
    final required =
        ((spec['required'] as List?) ?? const []).cast<String>().toSet();
    final pluralParam = spec['plural_param'] as String?;
    final inlined =
        ((spec['inlined_enums'] as List?) ?? const []).cast<String>();

    final tokens = <String>[];
    for (final axis in axisOrder) {
      if (axis == pluralToken) {
        if (pluralParam == null || !args.containsKey(pluralParam)) {
          throw MissingRequiredAxis('$sid: plural param required');
        }
        tokens.add(pluralCategory(locale, args[pluralParam]));
      } else if (inlined.contains(axis)) {
        if (!args.containsKey(axis)) {
          throw MissingRequiredAxis("$sid: enum '$axis' required");
        }
        tokens.add(args[axis].toString());
      } else {
        if (args.containsKey(axis)) {
          tokens.add(args[axis].toString());
        } else if (required.contains(axis)) {
          throw MissingRequiredAxis("$sid: axis '$axis' required");
        } else {
          final vals = (freeAxes[axis] as List?)?.cast<String>() ?? const [];
          tokens.add(vals.isNotEmpty ? vals[0] : '');
        }
      }
    }

    final templates = (spec['templates'] as Map?) ?? const {};
    var template = templates[tokens.join('|')] as String?;
    template ??= templates.isNotEmpty
        ? templates.values.first as String
        : (spec['text'] as String? ?? '');

    final enumValues = (spec['enum_values'] as Map?) ?? const {};
    return _substituteAsync(template, locale, spec, args, enumValues);
  }

  String _substitute(String template, String locale, Map<String, dynamic> spec,
      Map<String, Object?> args, Map enumValues) {
    final fmt = (spec['fmt'] as Map?) ?? const {};
    final numberParams =
        ((fmt['number'] as List?) ?? const []).cast<String>().toSet();
    final dateField = fmt['date'];
    final Map dateFmts = dateField is Map ? dateField : const {};
    final Set<String> dateParams = dateField is Map
        ? dateField.keys.cast<String>().toSet()
        : ((dateField as List?) ?? const []).cast<String>().toSet();
    final currencyParams = (fmt['currency'] as Map?) ?? const {};
    final relativeParams =
        ((fmt['relative'] as List?) ?? const []).cast<String>().toSet();
    final enums = (spec['enums'] as Map?) ?? const {};
    final userAdapted =
        ((spec['user_adapted'] as List?) ?? const []).cast<String>().toSet();
    final uaContext = (spec['user_adapted_context'] as Map?) ?? const {};
    final digits = (spec['digit_conversion'] as bool?) ?? true;

    String conv(String s) => digits ? convertDigits(s, locale) : s;

    return template.replaceAllMapped(_placeholderRe, (m) {
      final name = m.group(1)!;
      if (!args.containsKey(name)) return m.group(0)!;
      final raw = args[name];

      if (enums.containsKey(name) && enumValues.containsKey(name)) {
        final map = enumValues[name] as Map;
        return (map[raw.toString()] ?? raw.toString()).toString();
      }
      if (dateParams.contains(name)) {
        return conv(formatDateValue(raw!, locale, dateFmts[name] as String?));
      }
      if (currencyParams.containsKey(name)) {
        return conv(
            formatCurrencyValue(raw!, locale, currencyParams[name] as String?));
      }
      if (relativeParams.contains(name)) {
        return conv(formatRelativeValue(raw!, locale));
      }
      if (numberParams.contains(name)) {
        return conv(raw.toString());
      }
      if (userAdapted.contains(name)) {
        return _adapt(raw.toString(), locale, uaContext[name] as String?);
      }
      return raw.toString();
    });
  }

  String _adapt(String value, String locale, String? context) {
    if (locale.split('-')[0] == _sourceLocale.split('-')[0]) return value;
    final runtimeAdapter = adapter ?? _syncDefaultAdapter();
    if (runtimeAdapter == null) return value;
    try {
      if (userAdaptedMode == UserAdaptedMode.realtime) {
        return runtimeAdapter(value, locale, context);
      }
      final key = '$value\u0000$locale\u0000${context ?? ''}';
      final adapted = runtimeAdapter(value, locale, context);
      if (adapted == value) return value;
      return _adaptCache.putIfAbsent(key, () => adapted);
    } catch (_) {
      // Runtime adaptation should not break UI rendering.
      return value;
    }
  }

  Future<String> _substituteAsync(
      String template,
      String locale,
      Map<String, dynamic> spec,
      Map<String, Object?> args,
      Map enumValues) async {
    final fmt = (spec['fmt'] as Map?) ?? const {};
    final numberParams =
        ((fmt['number'] as List?) ?? const []).cast<String>().toSet();
    final dateField = fmt['date'];
    final Map dateFmts = dateField is Map ? dateField : const {};
    final Set<String> dateParams = dateField is Map
        ? dateField.keys.cast<String>().toSet()
        : ((dateField as List?) ?? const []).cast<String>().toSet();
    final currencyParams = (fmt['currency'] as Map?) ?? const {};
    final relativeParams =
        ((fmt['relative'] as List?) ?? const []).cast<String>().toSet();
    final enums = (spec['enums'] as Map?) ?? const {};
    final userAdapted =
        ((spec['user_adapted'] as List?) ?? const []).cast<String>().toSet();
    final uaContext = (spec['user_adapted_context'] as Map?) ?? const {};
    final digits = (spec['digit_conversion'] as bool?) ?? true;

    String conv(String s) => digits ? convertDigits(s, locale) : s;

    final buffer = StringBuffer();
    var last = 0;
    for (final match in _placeholderRe.allMatches(template)) {
      buffer.write(template.substring(last, match.start));
      last = match.end;

      final name = match.group(1)!;
      if (!args.containsKey(name)) {
        buffer.write(match.group(0)!);
        continue;
      }
      final raw = args[name];

      if (enums.containsKey(name) && enumValues.containsKey(name)) {
        final map = enumValues[name] as Map;
        buffer.write((map[raw.toString()] ?? raw.toString()).toString());
        continue;
      }
      if (dateParams.contains(name)) {
        buffer.write(
            conv(formatDateValue(raw!, locale, dateFmts[name] as String?)));
        continue;
      }
      if (currencyParams.containsKey(name)) {
        buffer.write(conv(formatCurrencyValue(
            raw!, locale, currencyParams[name] as String?)));
        continue;
      }
      if (relativeParams.contains(name)) {
        buffer.write(conv(formatRelativeValue(raw!, locale)));
        continue;
      }
      if (numberParams.contains(name)) {
        buffer.write(conv(raw.toString()));
        continue;
      }
      if (userAdapted.contains(name)) {
        buffer.write(await _adaptAsync(
            raw.toString(), locale, uaContext[name] as String?));
        continue;
      }
      buffer.write(raw.toString());
    }
    buffer.write(template.substring(last));
    return buffer.toString();
  }

  Future<String> _adaptAsync(
      String value, String locale, String? context) async {
    if (locale.split('-')[0] == _sourceLocale.split('-')[0]) return value;
    if (asyncAdapter == null && adapter != null) {
      // If caller provided a sync adapter, keep it authoritative for async
      // resolution too (tests and deterministic app overrides).
      return _adapt(value, locale, context);
    }
    final runtimeAdapter = asyncAdapter ?? _asyncDefaultAdapter();
    if (runtimeAdapter == null) return _adapt(value, locale, context);
    try {
      if (userAdaptedMode == UserAdaptedMode.realtime) {
        return await runtimeAdapter(value, locale, context);
      }
      final key = '$value\u0000$locale\u0000${context ?? ''}';
      if (_adaptCache.containsKey(key)) return _adaptCache[key]!;
      final adapted = await runtimeAdapter(value, locale, context);
      if (adapted == value) return value;
      _adaptCache[key] = adapted;
      return adapted;
    } catch (_) {
      return value;
    }
  }

  Adapter? _syncDefaultAdapter() {
    if (!_defaultOpenRouterInitialized) {
      _defaultOpenRouterAdapter = openrouter.defaultAdapter();
      _defaultOpenRouterInitialized = true;
    }
    return _defaultOpenRouterAdapter;
  }

  AsyncAdapter? _asyncDefaultAdapter() {
    if (!_defaultAsyncOpenRouterInitialized) {
      _defaultAsyncOpenRouterAdapter = openrouter.defaultAsyncAdapter();
      _defaultAsyncOpenRouterInitialized = true;
    }
    return _defaultAsyncOpenRouterAdapter;
  }
}
