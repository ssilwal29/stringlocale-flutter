import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'text.dart';
import 'llm.dart';
import 'plural_rule.dart';

String _sourceHash(String source) {
  // Stable 16-hex hash — two 32-bit FNV-1a accumulators kept positive.
  // No crypto dependency; only needs to be stable across runs for skip detection.
  var h1 = 0x811c9dc5;
  var h2 = 0x01000193;
  for (final byte in utf8.encode(source)) {
    h1 = ((h1 ^ byte) * 0x01000193) & 0x7FFFFFFF;
    h2 = ((h2 ^ (byte + 7)) * 0x85ebca6b) & 0x7FFFFFFF;
  }
  final hex1 = h1.toRadixString(16).padLeft(8, '0');
  final hex2 = h2.toRadixString(16).padLeft(8, '0');
  return (hex1 + hex2).substring(0, 16);
}

List<String> _parseLocaleArg(String value) {
  final idx = value.indexOf(':');
  if (idx == -1) return [value.trim(), value.trim()];
  return [value.substring(0, idx).trim(), value.substring(idx + 1).trim()];
}

void _validatePlaceholders(
  String source,
  String translated,
  String label, {
  Set<String> allowedMissing = const {},
}) {
  final src = extractPlaceholders(source);
  final tr = extractPlaceholders(translated);
  final missing = src.difference(tr).difference(allowedMissing);
  final extra = tr.difference(src);
  if (missing.isNotEmpty) {
    throw FormatException(
      '[$label] Translation dropped placeholders: {${missing.join(', ')}}\n'
      '  source: $source\n  translated: $translated',
    );
  }
  if (extra.isNotEmpty) {
    throw FormatException(
      '[$label] Translation added unexpected placeholders: {${extra.join(', ')}}',
    );
  }
}

String _pluralCountParam(Message text) {
  for (final p in text.params) {
    if (p.kind == ParamKind.numberPlural) return p.name;
  }
  return 'count';
}

Map<String, dynamic> _loadJson(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Future<Map<String, Map<String, String>>> compileLocales({
  required List<Message> texts,
  required List<String> locales,
  String localeDir = 'locales',
  String model = defaultModel,
  String? apiKey,
  bool force = false,
  http.Client? client,
}) async {
  Directory(localeDir).createSync(recursive: true);
  final results = <String, Map<String, String>>{};

  for (final rawLocale in locales) {
    final parsed = _parseLocaleArg(rawLocale);
    final localeCode = parsed[0];
    final languageName = parsed[1];
    stdout.writeln('\n[$localeCode] Compiling $languageName...');

    final existing = _loadJson('$localeDir/$localeCode.json');
    final overrides = _loadJson('$localeDir/overrides/$localeCode.json');
    final output = <String, dynamic>{};

    for (final text in texts) {
      final hash = _sourceHash(text.source);
      final existingEntry = existing[text.key] as Map<String, dynamic>?;

      // Warn on stale override
      if (overrides.containsKey(text.key)) {
        final prevHash = existingEntry?['src_hash'];
        if (prevHash != null && prevHash != hash) {
          stdout.writeln(
              '  ⚠ ${text.key}: source changed, override may be stale');
        }
      }

      // Skip if unchanged
      if (!force &&
          existingEntry != null &&
          existingEntry['src_hash'] == hash) {
        output[text.key] = existingEntry;
        stdout.writeln('  skip  ${text.key}');
        continue;
      }

      stdout.write('  trans ${text.key} ... ');

      if (text.isPlural) {
        final parts = text.source.split(pluralSep);
        final countParam = _pluralCountParam(text);
        final result = await translatePlural(
          parts[0],
          parts[1],
          localeCode,
          languageName,
          countParam,
          model: model,
          apiKey: apiKey,
          client: client,
        );
        _validatePlaceholders(
          parts[0],
          result.singular,
          '${text.key}.singular',
          allowedMissing: {countParam},
        );
        _validatePlaceholders(
          parts[1],
          result.plural,
          '${text.key}.plural',
          allowedMissing: {countParam},
        );
        PluralRuleEvaluator(countParam).validate(result.rule);

        output[text.key] = {
          'singular': result.singular,
          'plural': result.plural,
          'rule': result.rule,
          'rule_explanation': result.ruleExplanation,
          'src_hash': hash,
        };
        stdout.writeln('→ singular="${result.singular}" rule="${result.rule}"');
      } else {
        final translated = await translateString(
          text.source,
          localeCode,
          languageName,
          model: model,
          apiKey: apiKey,
          client: client,
        );
        _validatePlaceholders(text.source, translated, text.key);
        output[text.key] = {'text': translated, 'src_hash': hash};
        stdout.writeln('→ "$translated"');
      }
    }

    final outFile = File('$localeDir/$localeCode.json');
    outFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(output)}\n');
    stdout.writeln('  wrote ${outFile.path}');

    results[localeCode] = {
      for (final e in output.entries)
        e.key: (e.value['text'] ?? e.value['plural'] ?? '') as String,
    };
  }

  stdout.writeln('\nCompilation complete.');
  return results;
}
