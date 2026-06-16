/// Build-time compiler for StringLocale declarations.
///
/// Output: split (`bundle.<locale>.json` + manifest.json) or combined.
/// Incremental: per-cell hash; unchanged cells reused on recompile.
///
/// Because Dart can't dynamically import a file by path, the idiomatic usage is
/// a project build script that imports its strings (auto-registering them) and
/// calls compileAll(...). See example/build.dart.
library;

import 'dart:convert';
import 'dart:io';

import '../runtime/string.dart';
import '../runtime/bundle.dart' show pluralToken;
import '../runtime/plural_rules.dart';
import 'llm.dart';

const Map<String, String> _languageNames = {
  'en': 'English',
  'ne': 'Nepali',
  'hi': 'Hindi',
  'ja': 'Japanese',
  'zh': 'Chinese',
  'ar': 'Arabic',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'nl': 'Dutch',
  'pt': 'Portuguese',
  'it': 'Italian',
  'ru': 'Russian',
  'ko': 'Korean',
  'bn': 'Bengali',
  'ta': 'Tamil',
  'tr': 'Turkish',
  'pl': 'Polish',
  'sw': 'Swahili',
  'th': 'Thai',
};

String _languageName(String locale) =>
    _languageNames[locale.replaceAll('_', '-').split('-')[0].toLowerCase()] ??
    locale;

/// Stable 16-hex hash (two 32-bit FNV-1a accumulators kept positive).
String slHash(List<String> parts) {
  final src = parts.join('\u0000');
  var h1 = 0x811c9dc5;
  var h2 = 0x01000193;
  for (final byte in utf8.encode(src)) {
    h1 = ((h1 ^ byte) * 0x01000193) & 0x7FFFFFFF;
    h2 = ((h2 ^ (byte + 7)) * 0x85ebca6b) & 0x7FFFFFFF;
  }
  final hex1 = h1.toRadixString(16).padLeft(8, '0');
  final hex2 = h2.toRadixString(16).padLeft(8, '0');
  return (hex1 + hex2).substring(0, 16);
}

Map<String, List<String>> _axisOptions(StringLocale s, String locale) {
  final opts = <String, List<String>>{};
  for (final axis in s.templateAxisOrder) {
    if (axis == pluralToken) {
      opts[axis] = pluralCategories(locale);
    } else if (s.inlinedEnums.contains(axis)) {
      opts[axis] = s.enums[axis]!;
    } else {
      opts[axis] = s.freeAxes[axis]!;
    }
  }
  return opts;
}

String _axisDesc(StringLocale s, Map<String, String> combo) {
  final parts = <String>[];
  combo.forEach((axis, tok) {
    if (axis == pluralToken) {
      parts.add('plural form: ${categoryHint(tok)}');
    } else if (s.inlinedEnums.contains(axis)) {
      parts.add('$axis = $tok');
    } else {
      parts.add('$axis: $tok');
    }
  });
  return parts.join('; ');
}

Map<String, dynamic> _meta(StringLocale s) => {
      'text': s.text,
      'axis_order': s.templateAxisOrder,
      'free_axes': s.freeAxes,
      'plural_param': s.pluralParam,
      'inlined_enums': s.inlinedEnums,
      'enums': s.substitutedEnums,
      'required': s.required,
      'digit_conversion': s.digitConversion,
      'fmt': {
        'number': s.number,
        'date': s.date,
        'currency': s.currency,
        'relative': s.relative,
      },
      'user_adapted': s.userAdapted,
      'user_adapted_context': s.userAdaptedContext,
    };

List<Map<String, String>> _combos(
    List<String> axisOrder, Map<String, List<String>> options) {
  if (axisOrder.isEmpty) return [{}];
  var acc = <Map<String, String>>[{}];
  for (final axis in axisOrder) {
    final next = <Map<String, String>>[];
    for (final partial in acc) {
      for (final val in options[axis]!) {
        next.add({...partial, axis: val});
      }
    }
    acc = next;
  }
  return acc;
}

/// Build one string's spec for one locale, reusing unchanged cells.
/// [draftTemplate]/[draftEnum] are async to support the OpenRouter drafter.
Future<Map<String, dynamic>> _compileLocaleSpec(
  StringLocale s,
  String locale,
  Future<String> Function(
          String text, String loc, String lang, String desc, Set<String> ph)
      draftTemplate,
  Future<String> Function(String value, String loc, String lang, String? ctx)
      draftEnum,
  Map<String, dynamic>? existing,
  bool force,
  String drafterCacheKey,
) async {
  final language = _languageName(locale);
  final meta = _meta(s);

  final prevTemplates = (existing?['templates'] as Map?) ?? const {};
  final prevThashes = (existing?['cell_hashes'] as Map?) ?? const {};
  final prevEnums = (existing?['enum_values'] as Map?) ?? const {};
  final prevEhashes = (existing?['enum_hashes'] as Map?) ?? const {};

  final options = _axisOptions(s, locale);
  final axisOrder = s.templateAxisOrder;
  final templates = <String, String>{};
  final cellHashes = <String, String>{};

  for (final combo in _combos(axisOrder, options)) {
    final key =
        axisOrder.isEmpty ? '' : axisOrder.map((a) => combo[a]).join('|');
    final desc = _axisDesc(s, combo);
    final h = slHash([s.text, key, locale, drafterCacheKey]);
    if (!force && prevThashes[key] == h && prevTemplates.containsKey(key)) {
      templates[key] = prevTemplates[key] as String;
    } else {
      templates[key] =
          await draftTemplate(s.text, locale, language, desc, s.placeholders);
    }
    cellHashes[key] = h;
  }

  final enumValues = <String, Map<String, String>>{};
  final enumHashes = <String, Map<String, String>>{};
  s.substitutedEnums.forEach((param, values) {
    enumValues[param] = {};
    enumHashes[param] = {};
  });
  for (final entry in s.substitutedEnums.entries) {
    final param = entry.key;
    for (final v in entry.value) {
      final h = slHash([v, locale, param, drafterCacheKey]);
      final prevMap = (prevEnums[param] as Map?) ?? const {};
      final prevHashMap = (prevEhashes[param] as Map?) ?? const {};
      if (!force && prevHashMap[v] == h && prevMap.containsKey(v)) {
        enumValues[param]![v] = prevMap[v] as String;
      } else {
        enumValues[param]![v] = await draftEnum(
            v, locale, language, s.enumContext[param] ?? '$param value');
      }
      enumHashes[param]![v] = h;
    }
  }

  return {
    ...meta,
    'locale': locale,
    'templates': templates,
    'enum_values': enumValues,
    'cell_hashes': cellHashes,
    'enum_hashes': enumHashes,
  };
}

class CompileResult {
  CompileResult(this.perLocale, this.sourceLocale, this.locales,
      [this.translation]);

  final Map<String, Map<String, dynamic>> perLocale;
  final String sourceLocale;
  final List<String> locales;
  final Map<String, dynamic>? translation;

  int cellCount() {
    var total = 0;
    for (final data in perLocale.values) {
      final strings = data['strings'] as Map;
      for (final spec in strings.values) {
        total += (spec['templates'] as Map).length;
        for (final vals in (spec['enum_values'] as Map).values) {
          total += (vals as Map).length;
        }
      }
    }
    return total;
  }

  /// Write `dist/bundle.<locale>.json` + manifest.json.
  void writeSplit(String outDir) {
    Directory(outDir).createSync(recursive: true);
    final files = <String, dynamic>{};
    perLocale.forEach((locale, data) {
      final payload = '${const JsonEncoder.withIndent('  ').convert(data)}\n';
      final fname = 'bundle.$locale.json';
      File('$outDir/$fname').writeAsStringSync(payload);
      files[locale] = {
        'path': fname,
        'hash': slHash([payload])
      };
    });
    final manifest = {
      'version': 1,
      'source_locale': sourceLocale,
      'locales': locales,
      if (translation != null) 'translation': translation,
      'files': files,
    };
    File('$outDir/manifest.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  }

  /// Write one combined bundle.json (all locales).
  void writeCombined(String path) {
    final strings = <String, dynamic>{};
    perLocale.forEach((locale, data) {
      (data['strings'] as Map).forEach((sid, spec) {
        final specMap = spec as Map;
        if (!strings.containsKey(sid)) {
          final meta = <String, dynamic>{
            for (final e in specMap.entries)
              if (![
                'templates',
                'enum_values',
                'cell_hashes',
                'enum_hashes',
                'locale'
              ].contains(e.key))
                e.key: e.value
          };
          strings[sid] = {...meta, 'cells': <String, dynamic>{}};
        }
        (strings[sid]['cells'] as Map)[locale] = {
          'templates': specMap['templates'],
          'enums': specMap['enum_values'],
        };
      });
    });
    final combined = {
      'version': 1,
      'source_locale': sourceLocale,
      'locales': locales,
      if (translation != null) 'translation': translation,
      'strings': strings,
    };
    final f = File(path);
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(combined)}\n');
  }
}

Map<String, Map<String, dynamic>> _loadExistingSplit(String? outDir) {
  if (outDir == null) return {};
  final manifest = File('$outDir/manifest.json');
  if (!manifest.existsSync()) return {};
  final m = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
  final existing = <String, Map<String, dynamic>>{};
  final files = (m['files'] as Map?) ?? {};
  files.forEach((locale, entry) {
    final f = File('$outDir/${(entry as Map)['path']}');
    if (f.existsSync()) {
      existing[locale as String] =
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }
  });
  return existing;
}

String _drafterCacheKey(Object drafter) {
  if (drafter is OpenRouterDrafter) return 'openrouter:${drafter.model}';
  if (drafter is OfflineDrafter) return 'offline';
  return drafter.runtimeType.toString();
}

Map<String, dynamic> _translationInfo(Object drafter) {
  if (drafter is OpenRouterDrafter) {
    return {'drafter': 'openrouter', 'model': drafter.model};
  }
  if (drafter is OfflineDrafter) return {'drafter': 'offline'};
  return {'drafter': drafter.runtimeType.toString()};
}

/// Parse "code:Language" (or just "code") to the locale code.
String parseLocaleArg(String value) => value.split(':')[0].trim();

/// Compile an explicit list. Drafters can be OfflineDrafter or OpenRouterDrafter.
Future<CompileResult> compileStrings({
  required List<StringLocale> strings,
  required List<String> locales,
  Object? drafter,
  String sourceLocale = 'en',
  bool force = false,
  String? existingDir,
  void Function(String)? log,
}) async {
  final d = drafter ?? OfflineDrafter();

  // Adapt either drafter type to async closures.
  Future<String> draftTemplate(
      String text, String loc, String lang, String desc, Set<String> ph) async {
    if (d is OpenRouterDrafter) {
      return d.draftTemplate(text, loc, lang, desc, ph);
    }
    if (d is Drafter) return d.draftTemplate(text, loc, lang, desc, ph);
    throw ArgumentError('Unknown drafter type');
  }

  Future<String> draftEnum(
      String v, String loc, String lang, String? ctx) async {
    if (d is OpenRouterDrafter) return d.draftEnum(v, loc, lang, ctx);
    if (d is Drafter) return d.draftEnum(v, loc, lang, ctx);
    throw ArgumentError('Unknown drafter type');
  }

  final existing = _loadExistingSplit(existingDir);
  final perLocale = <String, Map<String, dynamic>>{};
  final translation = _translationInfo(d);
  final drafterCacheKey = _drafterCacheKey(d);

  for (final locale in locales) {
    log?.call('[$locale] ${_languageName(locale)}');
    final existingStrings = (existing[locale]?['strings'] as Map?) ?? const {};
    final outStrings = <String, dynamic>{};
    for (final s in strings) {
      final prev = existingStrings[s.id] as Map<String, dynamic>?;
      outStrings[s.id] = await _compileLocaleSpec(
          s, locale, draftTemplate, draftEnum, prev, force, drafterCacheKey);
    }
    perLocale[locale] = {
      'version': 1,
      'locale': locale,
      'source_locale': sourceLocale,
      'translation': translation,
      'strings': outStrings,
    };
  }
  return CompileResult(perLocale, sourceLocale, locales, translation);
}

/// Sweep the global registry and compile every declared string.
Future<CompileResult> compileAll({
  required List<String> locales,
  Object? drafter,
  String sourceLocale = 'en',
  bool force = false,
  String? existingDir,
  void Function(String)? log,
}) {
  return compileStrings(
    strings: getRegistry().values.toList(),
    locales: locales,
    drafter: drafter,
    sourceLocale: sourceLocale,
    force: force,
    existingDir: existingDir,
    log: log,
  );
}
