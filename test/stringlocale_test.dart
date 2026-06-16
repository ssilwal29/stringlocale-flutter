import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stringlocale/stringlocale.dart';
import 'package:stringlocale/compile.dart';

// In-memory file reader for tests that write a temp dist dir.
String? _reader(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync() : null;
}

void main() {
  setUp(() {
    clearRegistry();
    useBundle(null);
    setLocale('en');
  });
  tearDown(() {
    clearRegistry();
    useBundle(null);
    setLocale('en');
  });

  group('plural rules', () {
    test('en', () {
      expect(pluralCategory('en', 1), 'one');
      expect(pluralCategory('en', 2), 'other');
    });
    test('ar', () {
      expect(pluralCategory('ar', 0), 'zero');
      expect(pluralCategory('ar', 2), 'two');
      expect(pluralCategory('ar', 3), 'few');
    });
    test('ja single', () => expect(pluralCategories('ja'), ['other']));
    test('ru', () {
      expect(pluralCategory('ru', 1), 'one');
      expect(pluralCategory('ru', 2), 'few');
      expect(pluralCategory('ru', 5), 'many');
    });
    test('CLDR decimal operands', () {
      expect(pluralCategory('cs', 1), 'one');
      expect(pluralCategory('cs', 2), 'few');
      expect(pluralCategory('cs', '1.5'), 'many');
      expect(pluralCategory('en', '1.0'), 'other');
    });
    test('CLDR regional and expanded categories', () {
      expect(pluralCategories('pt'), ['one', 'many', 'other']);
      expect(pluralCategories('pt-PT'), ['one', 'many', 'other']);
      expect(pluralCategory('pt', 0), 'one');
      expect(pluralCategory('pt-PT', 0), 'other');
      expect(pluralCategory('he', 2), 'two');
    });
  });

  group('Param', () {
    test('kinds', () {
      expect(Param.literal().kind, ParamKind.literal);
      expect(Param.plural().kind, ParamKind.plural);
      expect(Param.translatable(['a', 'b']).values, ['a', 'b']);
      expect(Param.currency('NPR').currencyCode, 'NPR');
      expect(Param.date('long').fmt, 'long');
    });
  });

  group('StringLocale declaration', () {
    test('sorts params', () {
      final s = StringLocale('{n} {c} {s} {d} {f}', id: 'x', params: {
        'n': Param.literal(),
        'c': Param.plural(),
        's': Param.translatable(['a', 'b']),
        'd': Param.date(),
        'f': Param.currency('USD'),
      });
      expect(s.pluralParam, 'c');
      expect(s.enums.containsKey('s'), true);
      expect(s.date.containsKey('d'), true);
      expect(s.currency['f'], 'USD');
      expect(s.number.contains('c'), true);
    });

    test('param not placeholder throws', () {
      expect(
          () => StringLocale('hello',
              id: 'x', params: {'ghost': Param.literal()}),
          throwsArgumentError);
    });

    test('two plurals throws', () {
      expect(
          () => StringLocale('{a} {b}',
              id: 'x', params: {'a': Param.plural(), 'b': Param.plural()}),
          throwsArgumentError);
    });

    test('gendered axis', () {
      final s = StringLocale('he {x}',
          id: 'g', params: {'x': Param.number()}, gendered: true);
      expect(s.freeAxes.containsKey('gender'), true);
      expect(s.required.contains('gender'), true);
    });

    test('duplicate throws', () {
      StringLocale('A', id: 'd');
      expect(() => StringLocale('B', id: 'd'), throwsArgumentError);
    });

    test('duplicate with different metadata throws', () {
      StringLocale('Count {n}',
          id: 'same_text', params: {'n': Param.literal()});
      expect(
        () => StringLocale('Count {n}',
            id: 'same_text', params: {'n': Param.number()}),
        throwsArgumentError,
      );
    });

    test('inlined vs substituted', () {
      final s = StringLocale('{a} {b}', id: 'x', params: {
        'a': Param.translatable(['1']),
        'b': Param.translatable(['2'], inline: true),
      });
      expect(s.inlinedEnums.contains('b'), true);
      expect(s.substitutedEnums.containsKey('a'), true);
      expect(s.substitutedEnums.containsKey('b'), false);
    });
  });

  group('compile + resolve', () {
    Future<Bundle> build(List<StringLocale> strings, List<String> locales,
        {Adapter? adapter}) async {
      final r = await compileStrings(
          strings: strings, locales: locales, drafter: OfflineDrafter());
      // combine all per-locale into one in-memory bundle
      Bundle? b;
      for (final data in r.perLocale.values) {
        if (b == null) {
          b = Bundle(
            data,
            adapter: adapter ?? ((value, locale, context) => value),
          );
        } else {
          // merge via a fresh combined approach: write+read is overkill; use _merge
          b = _mergeInto(b, data);
        }
      }
      return b!;
    }

    test('static', () async {
      final s = StringLocale('Welcome', id: 'w');
      final b = await build([s], ['en', 'ne']);
      expect(b.resolve('en', 'w'), 'Welcome');
      expect(b.resolve('ne', 'w').startsWith('ne:'), true);
    });

    test('plural digit conversion', () async {
      final s = StringLocale('{count} items',
          id: 'c', params: {'count': Param.plural()});
      final b = await build([s], ['ne']);
      expect(b.resolve('ne', 'c', {'count': 12}).contains('१२'), true);
    });

    test('enum substitution', () async {
      final s = StringLocale('Status {st}', id: 's', params: {
        'st': Param.translatable(['approved', 'pending'])
      });
      final b = await build([s], ['ne']);
      expect(b.resolve('ne', 's', {'st': 'approved'}).contains('ne:approved'),
          true);
    });

    test('currency', () async {
      final s = StringLocale('{amt}',
          id: 'p', params: {'amt': Param.currency('NPR')});
      final b = await build([s], ['ne']);
      final out = b.resolve('ne', 'p', {'amt': 2500});
      expect(out.contains('२,५००') || out.contains('2,500'), true);
    });

    test('required axis throws', () async {
      final s = StringLocale('he {x}',
          id: 'g', params: {'x': Param.number()}, gendered: true);
      final b = await build([s], ['en']);
      expect(() => b.resolve('en', 'g', {'x': 1}),
          throwsA(isA<MissingRequiredAxis>()));
    });

    test('user passthrough', () async {
      final s = StringLocale('Bio {b}', id: 'u', params: {'b': Param.user()});
      final b = await build([s], ['ne']);
      expect(b.resolve('ne', 'u', {'b': 'my text'}).contains('my text'), true);
    });

    test('userAdapted offline passthrough', () async {
      final s =
          StringLocale('Bio {b}', id: 'u', params: {'b': Param.userAdapted()});
      final b = await build([s], ['ne']);
      expect(
          b.resolve(
              'ne', 'u', {'b': '1200 followers'}).contains('1200 followers'),
          true);
    });

    test('userAdapted adapter receives context and caches by tuple', () async {
      final s = StringLocale(
        'Bio {b}',
        id: 'u_ctx',
        params: {
          'b': Param.userAdapted(context: 'Marketplace profile bio'),
        },
      );
      final r = await compileStrings(
        strings: [s],
        locales: ['en-US', 'ne-NP'],
        sourceLocale: 'en-US',
        drafter: OfflineDrafter(),
      );

      var calls = 0;
      String? seenContext;
      Bundle? b;
      for (final data in r.perLocale.values) {
        if (b == null) {
          b = Bundle(
            data,
            adapter: (value, locale, context) {
              calls += 1;
              seenContext = context;
              return 'adapt<$locale|${context ?? ''}>:$value';
            },
          );
        } else {
          b = _mergeInto(b, data);
        }
      }

      final first = b!.resolve('ne-NP', 'u_ctx', {'b': '1200 followers'});
      final second = b.resolve('ne-NP', 'u_ctx', {'b': '1200 followers'});
      final source = b.resolve('en-US', 'u_ctx', {'b': '1200 followers'});

      expect(
          first.contains('adapt<ne-NP|Marketplace profile bio>:1200 followers'),
          true);
      expect(second, first);
      expect(source.contains('1200 followers'), true);
      expect(source.contains('adapt<'), false);
      expect(calls, 2);
      expect(seenContext, 'Marketplace profile bio');
    });

    test('default OpenRouter adapter can be enabled by env', () async {
      final apiKey = Platform.environment['OPENROUTER_API_KEY'] ?? '';
      if (apiKey.isEmpty) return;

      final b = Bundle(
        {
          'source_locale': 'en-US',
          'locale': 'ne-NP',
          'strings': {
            'u': {
              'text': 'Bio {b}',
              'user_adapted': ['b'],
              'user_adapted_context': {
                'b': 'Marketplace profile bio',
              },
              'axis_order': [],
            },
          },
        },
        userAdaptedMode: UserAdaptedMode.realtime,
      );

      final resolved =
          await b.resolveAsync('ne-NP', 'u', {'b': 'Short creator bio'});
      expect(resolved.contains('Short creator bio'), false);
      expect(resolved.isNotEmpty, true);
    }, skip: Platform.environment['OPENROUTER_API_KEY']?.isEmpty ?? true);
  });

  group('cell economics', () {
    test('additive', () async {
      final s = StringLocale('{n} {a} {b}', id: 'x', gendered: true, params: {
        'n': Param.literal(),
        'a': Param.translatable(['1', '2', '3']),
        'b': Param.translatable(['x', 'y']),
      });
      final r = await compileStrings(
          strings: [s], locales: ['ne'], drafter: OfflineDrafter());
      // gender(2) + a(3)+b(2)=5 => 7
      expect(r.cellCount(), 7);
    });

    test('cross product', () async {
      final s = StringLocale('{n} {a} {b}', id: 'x', gendered: true, params: {
        'n': Param.literal(),
        'a': Param.translatable(['1', '2', '3'], inline: true),
        'b': Param.translatable(['x', 'y'], inline: true),
      });
      final r = await compileStrings(
          strings: [s], locales: ['ne'], drafter: OfflineDrafter());
      // gender(2) x a(3) x b(2) = 12
      expect(r.cellCount(), 12);
    });
  });

  group('split / fallback / lazy', () {
    test('split + manifest + single-locale load', () async {
      final dir = Directory.systemTemp.createTempSync('sl_test_').path;
      final s = StringLocale('Hi {n}', id: 'h', params: {'n': Param.literal()});
      (await compileStrings(
              strings: [s],
              locales: ['en', 'ne-NP', 'ja-JP'],
              drafter: OfflineDrafter()))
          .writeSplit(dir);
      final files =
          Directory(dir).listSync().map((e) => e.uri.pathSegments.last).toSet();
      expect(files.contains('manifest.json'), true);
      expect(files.contains('bundle.ne-NP.json'), true);

      // load only ne-NP -> auto-loads en (source) for fallback
      final b = Bundle.fromDir(dir, _reader, locales: ['ne-NP']);
      expect(b.locales.contains('ne-NP'), true);
      expect(b.locales.contains('en'), true);
      expect(b.locales.contains('ja-JP'), false);
      expect(b.resolve('ne-NP', 'h', {'n': 'X'}).startsWith('ne:'), true);
    });

    test('region falls back to base', () async {
      final s = StringLocale('Hi {n}', id: 'h', params: {'n': Param.literal()});
      final r = await compileStrings(
          strings: [s], locales: ['en', 'pt'], drafter: OfflineDrafter());
      Bundle? b;
      for (final d in r.perLocale.values) {
        b = b == null ? Bundle(d) : _mergeInto(b, d);
      }
      // pt-BR not compiled -> pt
      expect(b!.resolve('pt-BR', 'h', {'n': 'X'}), 'pt:Hi X');
    });

    test('lazy ensureLocale loads custom fallback files', () async {
      final dir = Directory.systemTemp.createTempSync('sl_fb_').path;
      final s = StringLocale('Hi {n}', id: 'h', params: {'n': Param.literal()});
      (await compileStrings(
              strings: [s], locales: ['en', 'es'], drafter: OfflineDrafter()))
          .writeSplit(dir);

      final b = Bundle.fromDir(
        dir,
        _reader,
        locales: ['en'],
        fallbacks: {
          'pt-BR': ['es']
        },
      );
      expect(b.locales.contains('es'), false);
      b.ensureLocale('pt-BR');
      expect(b.resolve('pt-BR', 'h', {'n': 'X'}), 'es:Hi X');
    });
  });

  group('check + prune', () {
    test('clean check passes', () async {
      final dir = Directory.systemTemp.createTempSync('sl_chk_').path;
      final s = StringLocale('Hi {n}', id: 'h', params: {'n': Param.literal()});
      (await compileStrings(
              strings: [s], locales: ['en', 'ne'], drafter: OfflineDrafter()))
          .writeSplit(dir);
      final report = check([s], dir);
      expect(report.ok, true);
    });

    test('missing + orphaned detected', () async {
      final dir = Directory.systemTemp.createTempSync('sl_chk2_').path;
      final keep =
          StringLocale('Keep {x}', id: 'keep', params: {'x': Param.literal()});
      final gone =
          StringLocale('Gone {y}', id: 'gone', params: {'y': Param.literal()});
      (await compileStrings(
              strings: [keep, gone],
              locales: ['en'],
              drafter: OfflineDrafter()))
          .writeSplit(dir);
      clearRegistry();
      final keep2 =
          StringLocale('Keep {x}', id: 'keep', params: {'x': Param.literal()});
      final newOne =
          StringLocale('New {z}', id: 'new', params: {'z': Param.literal()});
      final report = check([keep2, newOne], dir);
      expect(report.orphaned.any((o) => o[1] == 'gone'), true);
      expect(report.missing.any((m) => m[1] == 'new'), true);
      expect(report.ok, false);
    });

    test('prune removes orphans, keeps survivors', () async {
      final dir = Directory.systemTemp.createTempSync('sl_prune_').path;
      final keep =
          StringLocale('Keep {x}', id: 'keep', params: {'x': Param.literal()});
      final gone =
          StringLocale('Gone {y}', id: 'gone', params: {'y': Param.literal()});
      (await compileStrings(
              strings: [keep, gone],
              locales: ['en', 'ne'],
              drafter: OfflineDrafter()))
          .writeSplit(dir);
      clearRegistry();
      final keep2 =
          StringLocale('Keep {x}', id: 'keep', params: {'x': Param.literal()});
      final result = prune([keep2], dir);
      expect(result.removed.any((r) => r[1] == 'gone'), true);
      final ne = jsonDecode(File('$dir/bundle.ne.json').readAsStringSync())
          as Map<String, dynamic>;
      expect((ne['strings'] as Map).containsKey('gone'), false);
      expect((ne['strings'] as Map).containsKey('keep'), true);
    });

    test('prune dry-run writes nothing', () async {
      final dir = Directory.systemTemp.createTempSync('sl_dry_').path;
      final keep =
          StringLocale('Keep {x}', id: 'keep', params: {'x': Param.literal()});
      final gone =
          StringLocale('Gone {y}', id: 'gone', params: {'y': Param.literal()});
      (await compileStrings(
              strings: [keep, gone],
              locales: ['en'],
              drafter: OfflineDrafter()))
          .writeSplit(dir);
      clearRegistry();
      final keep2 =
          StringLocale('Keep {x}', id: 'keep', params: {'x': Param.literal()});
      final result = prune([keep2], dir, dryRun: true);
      expect(result.removed.any((r) => r[1] == 'gone'), true);
      final en = jsonDecode(File('$dir/bundle.en.json').readAsStringSync())
          as Map<String, dynamic>;
      expect((en['strings'] as Map).containsKey('gone'), true); // not removed
    });

    test('inline enum still checks other placeholders', () async {
      final dir = Directory.systemTemp.createTempSync('sl_inline_chk_').path;
      final s =
          StringLocale('{count} items for {status}', id: 'inline', params: {
        'count': Param.plural(),
        'status': Param.translatable(['open'], inline: true),
      });
      (await compileStrings(
              strings: [s], locales: ['ne'], drafter: OfflineDrafter()))
          .writeSplit(dir);

      final file = File('$dir/bundle.ne.json');
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final spec = (data['strings'] as Map)['inline'] as Map;
      final templates = spec['templates'] as Map;
      templates.updateAll((_, __) => 'items for open');
      file.writeAsStringSync(jsonEncode(data));

      final report = check([s], dir);
      expect(report.placeholder.any((p) => p[1] == 'inline'), true);
    });
  });

  group('incremental', () {
    test('unchanged recompile reuses (no redraft)', () async {
      final dir = Directory.systemTemp.createTempSync('sl_inc_').path;
      final s =
          StringLocale('{count} x', id: 'c', params: {'count': Param.plural()});
      final initial = _CountingDrafter();
      (await compileStrings(
              strings: [s], locales: ['en', 'ne'], drafter: initial))
          .writeSplit(dir);
      expect(initial.calls, 4);

      final counting = _CountingDrafter();
      await compileStrings(
          strings: [s],
          locales: ['en', 'ne'],
          drafter: counting,
          existingDir: dir);
      expect(counting.calls, 0);
    });

    test('changed OpenRouter model redrafts cached cells', () async {
      final dir = Directory.systemTemp.createTempSync('sl_model_').path;
      final s = StringLocale('Welcome', id: 'welcome');
      final first = _CountingOpenRouterDrafter('model-a');
      (await compileStrings(strings: [s], locales: ['ne'], drafter: first))
          .writeSplit(dir);
      expect(first.calls, 1);

      final sameModel = _CountingOpenRouterDrafter('model-a');
      await compileStrings(
          strings: [s], locales: ['ne'], drafter: sameModel, existingDir: dir);
      expect(sameModel.calls, 0);

      final differentModel = _CountingOpenRouterDrafter('model-b');
      final result = await compileStrings(
          strings: [s],
          locales: ['ne'],
          drafter: differentModel,
          existingDir: dir);
      expect(differentModel.calls, 1);
      expect(result.translation, {'drafter': 'openrouter', 'model': 'model-b'});
    });

    test('custom drafter is accepted for fresh compile', () async {
      final s = StringLocale('Fresh', id: 'fresh');
      final counting = _CountingDrafter();
      final result = await compileStrings(
          strings: [s], locales: ['ne'], drafter: counting);
      expect(counting.calls, 1);
      expect(
        ((result.perLocale['ne']!['strings'] as Map)['fresh']
            as Map)['templates'][''],
        'T',
      );
    });
  });

  group('StringLocale.resolve with globals', () {
    test('uses current locale + bundle', () async {
      final dir = Directory.systemTemp.createTempSync('sl_glob_').path;
      final w = StringLocale('Welcome', id: 'w');
      (await compileStrings(
              strings: [w],
              locales: ['en', 'ne-NP'],
              drafter: OfflineDrafter()))
          .writeSplit(dir);
      final b = Bundle.fromDir(dir, _reader, locales: ['ne-NP']);
      useBundle(b, locale: 'ne-NP');
      expect(w.resolve().startsWith('ne:'), true);
    });

    test('naive fallback without bundle', () {
      useBundle(null);
      final s =
          StringLocale('Count {c}', id: 'naive', params: {'c': Param.number()});
      expect(s.resolve(locale: 'ne-NP', args: {'c': 12}).contains('१२'), true);
    });
  });
}

// Helper: merge a per-locale data map into an existing bundle via JSON round-trip.
Bundle _mergeInto(Bundle existing, Map<String, dynamic> data) {
  // Bundle has no public merge; reconstruct by writing both to a combined form.
  // Simplest: create a new bundle from a combined structure. For tests we just
  // build a fresh bundle that includes both by using the per-locale merge path.
  existing.mergeForTest(data);
  return existing;
}

class _CountingDrafter implements Drafter {
  int calls = 0;
  @override
  String draftTemplate(String baseText, String locale, String language,
      String axisDesc, Set<String> placeholders) {
    calls++;
    return 'T';
  }

  @override
  String draftEnum(
      String value, String locale, String language, String? context) {
    calls++;
    return 'E';
  }
}

class _CountingOpenRouterDrafter extends OpenRouterDrafter {
  _CountingOpenRouterDrafter(String model)
      : super(model: model, apiKey: 'test-key');

  int calls = 0;

  @override
  Future<String> draftTemplate(String baseText, String locale, String language,
      String axisDesc, Set<String> placeholders) async {
    calls++;
    return '$model:$baseText';
  }

  @override
  Future<String> draftEnum(
      String value, String locale, String language, String? context) async {
    calls++;
    return '$model:$value';
  }
}
