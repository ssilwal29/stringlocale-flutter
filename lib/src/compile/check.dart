/// `check` and `prune` — drift detection and orphan cleanup. Mirrors Python.
///
///   check: missing / orphaned / stale / placeholder (+ untranslated warning)
///   prune: remove orphaned (no-longer-declared) entries without re-drafting
library;

import 'dart:convert';
import 'dart:io';

import '../runtime/string.dart';
import 'compiler.dart' show slHash;

final RegExp _placeholderRe = RegExp(r'\{(\w+)\}');

Set<String> _placeholders(String s) =>
    _placeholderRe.allMatches(s).map((m) => m.group(1)!).toSet();

class Report {
  final List<List<String>> missing = []; // [locale, id]
  final List<List<String>> orphaned = []; // [locale, id]
  final List<List<String>> stale = []; // [locale, id]
  final List<List<String>> placeholder = []; // [locale, id, key]
  final List<List<String>> untranslated = []; // [locale, id, key]

  bool get ok =>
      missing.isEmpty &&
      orphaned.isEmpty &&
      stale.isEmpty &&
      placeholder.isEmpty;
  bool get hasWarnings => untranslated.isNotEmpty;

  String summary() {
    final lines = <String>[];
    for (final m in missing) {
      lines.add('  MISSING      [${m[0]}] ${m[1]} — declared but not compiled');
    }
    for (final o in orphaned) {
      lines.add(
          '  ORPHANED     [${o[0]}] ${o[1]} — compiled but no longer declared');
    }
    for (final s in stale) {
      lines.add(
          '  STALE        [${s[0]}] ${s[1]} — source changed since compile');
    }
    for (final p in placeholder) {
      lines.add(
          '  PLACEHOLDER  [${p[0]}] ${p[1]} (${p[2]}) — placeholder mismatch');
    }
    for (final u in untranslated) {
      lines.add('  UNTRANSLATED [${u[0]}] ${u[1]} (${u[2]}) — same as source');
    }
    return lines.isEmpty ? 'OK — no issues.' : lines.join('\n');
  }
}

Report check(
  List<StringLocale>? strings,
  String bundleDir, {
  List<String>? locales,
}) {
  final list = strings ?? getRegistry().values.toList();
  final declared = {for (final s in list) s.id: s};

  final manifest =
      jsonDecode(File('$bundleDir/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final source = (manifest['source_locale'] as String?) ?? 'en';
  final checkLocales = locales ?? (manifest['locales'] as List).cast<String>();
  final files = (manifest['files'] as Map?) ?? {};

  final report = Report();

  for (final locale in checkLocales) {
    final entry = files[locale] as Map?;
    Map compiled = {};
    if (entry != null) {
      final data =
          jsonDecode(File('$bundleDir/${entry['path']}').readAsStringSync())
              as Map<String, dynamic>;
      compiled = (data['strings'] as Map?) ?? {};
    }

    final compiledIds = compiled.keys.cast<String>().toSet();
    final declaredIds = declared.keys.toSet();

    for (final sid in declaredIds.difference(compiledIds)) {
      report.missing.add([locale, sid]);
    }
    for (final sid in compiledIds.difference(declaredIds)) {
      report.orphaned.add([locale, sid]);
    }

    for (final sid in declaredIds.intersection(compiledIds)) {
      final s = declared[sid]!;
      final spec = compiled[sid] as Map;

      if (spec['text'] != s.text) report.stale.add([locale, sid]);

      final templates = (spec['templates'] as Map?) ?? {};
      final srcPh = _placeholders(s.text);
      final inlined =
          ((spec['inlined_enums'] as List?) ?? const []).cast<String>().toSet();
      templates.forEach((key, value) {
        final vph = _placeholders(value as String);
        final allowedMissing = srcPh.intersection(inlined);
        final mismatch = vph.difference(srcPh).isNotEmpty ||
            srcPh.difference(allowedMissing).difference(vph).isNotEmpty;
        if (mismatch) {
          report.placeholder.add([locale, sid, key as String]);
        }
        if (locale.split('-')[0] != source.split('-')[0] && value == s.text) {
          report.untranslated.add([locale, sid, key as String]);
        }
      });
    }
  }
  return report;
}

class PruneResult {
  final List<List<String>> removed = []; // [locale, id]

  String summary() {
    if (removed.isEmpty) return 'Nothing to prune — no orphaned strings.';
    return removed.map((r) => '  removed [${r[0]}] ${r[1]}').join('\n');
  }
}

PruneResult prune(
  List<StringLocale>? strings,
  String bundleDir, {
  List<String>? locales,
  bool dryRun = false,
}) {
  final list = strings ?? getRegistry().values.toList();
  final declaredIds = {for (final s in list) s.id};

  final manifestFile = File('$bundleDir/manifest.json');
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final files = (manifest['files'] as Map?) ?? {};
  final targets = locales ?? files.keys.cast<String>().toList();

  final result = PruneResult();
  final changed = <String, String>{};

  for (final locale in targets) {
    final entry = files[locale] as Map?;
    if (entry == null) continue;
    final fpath = File('$bundleDir/${entry['path']}');
    final data = jsonDecode(fpath.readAsStringSync()) as Map<String, dynamic>;
    final stringsMap = (data['strings'] as Map?) ?? {};

    final orphans =
        stringsMap.keys.where((sid) => !declaredIds.contains(sid)).toList();
    if (orphans.isEmpty) continue;

    for (final sid in orphans) {
      result.removed.add([locale, sid as String]);
      if (!dryRun) stringsMap.remove(sid);
    }

    if (!dryRun) {
      final payload = '${const JsonEncoder.withIndent('  ').convert(data)}\n';
      fpath.writeAsStringSync(payload);
      changed[locale] = slHash([payload]);
    }
  }

  if (!dryRun && changed.isNotEmpty) {
    changed.forEach((locale, h) {
      (files[locale] as Map)['hash'] = h;
    });
    manifestFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  }

  return result;
}
