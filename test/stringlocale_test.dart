import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stringlocale/stringlocale_flutter.dart';

void main() {
  // ── text.dart ───────────────────────────────────────────────────────────────

  group('staticText', () {
    test('creates text with no params', () {
      final t = staticText('welcome', 'Welcome to stringlocale');
      expect(t.key, 'welcome');
      expect(t.source, 'Welcome to stringlocale');
      expect(t.isDynamic, false);
      expect(t.isPlural, false);
      expect(t.params, isEmpty);
    });
  });

  group('dynamicText', () {
    test('creates text with typed params', () {
      final t = dynamicText('count', 'You have {count} items', {
        'count': ParamKind.number,
      });
      expect(t.params.length, 1);
      expect(t.params[0].kind, ParamKind.number);
      expect(t.isDynamic, true);
    });

    test('accepts Param objects with context', () {
      final t = dynamicText('status', 'Status: {status}', {
        'status': const Param('status',
            kind: ParamKind.translatable, context: 'campaign status'),
      });
      expect(t.params[0].context, 'campaign status');
    });

    test('throws on undeclared placeholder', () {
      expect(
        () => dynamicText('x', 'Hello {name}', {}),
        throwsArgumentError,
      );
    });

    test('throws on extra param not in source', () {
      expect(
        () => dynamicText('x', 'Hello', {'extra': ParamKind.literal}),
        throwsArgumentError,
      );
    });

    test('param lookup', () {
      final t = dynamicText('x', '{a} and {b}', {
        'a': ParamKind.literal,
        'b': ParamKind.number,
      });
      expect(t.param('a')!.kind, ParamKind.literal);
      expect(t.param('c'), isNull);
    });

    test('message remains a backward-compatible alias', () {
      final t = message('count', 'You have {count} items', {
        'count': ParamKind.number,
      });
      expect(t.key, 'count');
      expect(t.params.single.kind, ParamKind.number);
    });

    test('dynamic_ remains a backward-compatible alias', () {
      final t = dynamic_('count', 'You have {count} items', {
        'count': ParamKind.number,
      });
      expect(t.key, 'count');
      expect(t.params.single.kind, ParamKind.number);
    });
  });

  group('pluralText', () {
    test('encodes both forms with pluralSep', () {
      final t = pluralText(
          'count', 'You have {count} item', 'You have {count} items');
      expect(t.source.contains(pluralSep), true);
      expect(t.isPlural, true);
    });

    test('marks count param as numberPlural', () {
      final t = pluralText('count', '{count} item', '{count} items');
      expect(t.params[0].kind, ParamKind.numberPlural);
      expect(t.params[0].name, 'count');
    });

    test('supports custom count param', () {
      final t = pluralText('x', '{n} item', '{n} items', countParam: 'n');
      expect(t.params[0].name, 'n');
    });

    test('supports extra params', () {
      final t = pluralText(
        'x',
        '{creator} has {count} item',
        '{creator} has {count} items',
        params: {'creator': ParamKind.literal},
      );
      expect(t.params.length, 2);
    });

    test('supports custom plural decider with extra typed params', () {
      final t = pluralText(
        'creator_campaign_count',
        '{creator} has {campaigns} active campaign worth {amount}',
        '{creator} has {campaigns} active campaigns worth {amount}',
        countParam: 'campaigns',
        params: {
          'creator': ParamKind.literal,
          'amount': const Param(
            'amount',
            kind: ParamKind.currency,
            currency: 'NPR',
          ),
        },
      );

      expect(t.params[0].name, 'campaigns');
      expect(t.params[0].kind, ParamKind.numberPlural);
      expect(t.param('creator')!.kind, ParamKind.literal);
      expect(t.param('amount')!.kind, ParamKind.currency);
    });

    test('throws on undeclared placeholder in either form', () {
      expect(
        () => pluralText(
            'x', 'You have {count} {missing} item', 'You have {count} items'),
        throwsArgumentError,
      );
    });

    test('plural remains a backward-compatible alias', () {
      final t = plural('count', '{count} item', '{count} items');
      expect(t.isPlural, true);
      expect(t.params.single.kind, ParamKind.numberPlural);
    });
  });

  // ── registry.dart ───────────────────────────────────────────────────────────

  group('Registry', () {
    test('registers and deduplicates', () {
      final r = Registry();
      final t = r.staticText('welcome', 'Welcome');
      expect(r.length, 1);
      expect(r.texts[0], t);
    });

    test('throws on duplicate key', () {
      final r = Registry();
      r.staticText('x', 'Hello');
      expect(() => r.staticText('x', 'World'), throwsArgumentError);
    });
  });

  // ── formatters.dart ─────────────────────────────────────────────────────────

  group('formatNumber', () {
    test('Nepali digits', () => expect(formatNumber(12, 'ne-NP'), '१२'));
    test('Hindi digits', () => expect(formatNumber(12, 'hi-IN'), '१२'));
    test('Marathi digits', () => expect(formatNumber(12, 'mr-IN'), '१२'));
    test('Arabic digits', () => expect(formatNumber(5, 'ar-SA'), '٥'));
    test('Persian digits', () => expect(formatNumber(12, 'fa-IR'), '۱۲'));
    test('Urdu digits', () => expect(formatNumber(12, 'ur-PK'), '۱۲'));
    test('Bengali digits', () => expect(formatNumber(12, 'bn-BD'), '১২'));
    test('Assamese digits', () => expect(formatNumber(12, 'as-IN'), '১২'));
    test('Gujarati digits', () => expect(formatNumber(12, 'gu-IN'), '૧૨'));
    test('Telugu digits', () => expect(formatNumber(12, 'te-IN'), '౧౨'));
    test('Kannada digits', () => expect(formatNumber(12, 'kn-IN'), '೧೨'));
    test('Malayalam digits', () => expect(formatNumber(12, 'ml-IN'), '൧൨'));
    test('Tamil digits', () => expect(formatNumber(12, 'ta-IN'), '௧௨'));
    test('Odia digits', () => expect(formatNumber(12, 'or-IN'), '୧୨'));
    test('Thai digits', () => expect(formatNumber(12, 'th-TH'), '๑๒'));
    test('Lao digits', () => expect(formatNumber(12, 'lo-LA'), '໑໒'));
    test('Myanmar digits', () => expect(formatNumber(12, 'my-MM'), '၁၂'));
    test('Khmer digits', () => expect(formatNumber(12, 'km-KH'), '១២'));
    test('Tibetan digits', () => expect(formatNumber(12, 'bo-CN'), '༡༢'));
    test('Punjabi Gurmukhi digits for explicit locale', () {
      expect(formatNumber(12, 'pa-IN'), '੧੨');
      expect(formatNumber(12, 'pa-Guru'), '੧੨');
    });
    test('Punjabi without explicit Gurmukhi locale falls back', () {
      expect(formatNumber(12, 'pa-PK'), '12');
    });
    test('ASCII-digit locales stay ASCII', () {
      expect(formatNumber(42, 'en'), '42');
      expect(formatNumber(42, 'ja-JP'), '42');
      expect(formatNumber(42, 'nl-NL'), '42');
      expect(formatNumber(42, 'zh-CN'), '42');
    });
    test('preserves non-digits',
        () => expect(formatNumber('2025-02', 'ne'), '२०२५-०२'));
  });

  group('formatRelativeValue', () {
    test('past', () {
      final r = formatRelativeValue(-86400 * 3, 'en');
      expect(r, contains('3'));
      expect(r.toLowerCase(), contains('day'));
    });
    test('future', () {
      final r = formatRelativeValue(86400 * 2, 'en');
      expect(r, contains('2'));
    });
  });

  // ── plural_rule.dart ────────────────────────────────────────────────────────

  group('PluralRuleEvaluator', () {
    final ev = PluralRuleEvaluator('count');

    test('simple comparison', () {
      expect(ev.eval('count < 2', 1), true);
      expect(ev.eval('count < 2', 2), false);
    });

    test('equality', () {
      expect(ev.eval('count == 1', 1), true);
      expect(ev.eval('count == 1', 0), false);
    });

    test('Russian rule', () {
      const rule = 'count % 10 == 1 && count % 100 != 11';
      expect(ev.eval(rule, 1), true);
      expect(ev.eval(rule, 11), false);
      expect(ev.eval(rule, 21), true);
      expect(ev.eval(rule, 111), false);
    });

    test('parentheses and or', () {
      expect(ev.eval('(count == 0) || (count == 1)', 0), true);
      expect(ev.eval('(count == 0) || (count == 1)', 2), false);
    });

    test('not operator', () {
      expect(ev.eval('!(count > 1)', 1), true);
      expect(ev.eval('!(count > 1)', 5), false);
    });

    test('falls back on bad rule', () {
      expect(ev.eval('not_valid!!!', 1), true);
      expect(ev.eval('garbage', 5), false);
    });

    test('validate rejects disallowed identifier', () {
      expect(
        () => ev.validate('count < 2 && evil'),
        throwsA(isA<FormatException>()),
      );
    });

    test('validate accepts good rule', () {
      ev.validate('count % 10 == 1 && count % 100 != 11');
    });

    test('validate accepts boolean literals', () {
      ev.validate('true');
      ev.validate('false');
    });
  });

  // ── renderer.dart ───────────────────────────────────────────────────────────

  group('Renderer', () {
    late Renderer r;

    setUp(() {
      r = Renderer(
        useDigitConversion: true,
        localeData: {
          'ne-NP': {
            'welcome': {'text': 'stringlocale मा स्वागत छ', 'src_hash': 'a'},
            'campaign_count': {
              'singular': 'तपाईंसँग {count} अभियान छ',
              'plural': 'तपाईंसँग {count} अभियानहरू छन्',
              'rule': 'count < 2',
              'src_hash': 'b',
            },
          },
        },
      );
    });

    test('static English', () async {
      final t = staticText('welcome', 'Welcome to stringlocale');
      expect(await r.render(t, 'en'), 'Welcome to stringlocale');
    });

    test('static Nepali', () async {
      final t = staticText('welcome', 'Welcome to stringlocale');
      expect(await r.render(t, 'ne-NP'), 'stringlocale मा स्वागत छ');
    });

    test('static fallback to source', () async {
      final t = staticText('unknown', 'Fallback');
      expect(await r.render(t, 'ne-NP'), 'Fallback');
    });

    test('number digit conversion', () async {
      final t = dynamicText(
          'x_count', 'You have {count} items', {'count': ParamKind.number});
      final result = await r.render(t, 'ne-NP', args: {'count': 12});
      expect(result, contains('१२'));
    });

    test('literal passthrough', () async {
      final t = dynamicText('price', '{creator} charges {amount}',
          {'creator': ParamKind.literal, 'amount': ParamKind.number});
      final result =
          await r.render(t, 'en', args: {'creator': 'Anisha', 'amount': 100});
      expect(result, contains('Anisha'));
      expect(result, contains('100'));
    });

    test('user passthrough', () async {
      final t =
          dynamicText('brief', 'Brief: {brief}', {'brief': ParamKind.user});
      final result =
          await r.render(t, 'ne-NP', args: {'brief': 'my user text'});
      expect(result, contains('my user text'));
    });

    test('missing param throws', () async {
      final t = dynamicText('x', 'Hello {name}', {'name': ParamKind.literal});
      expect(() => r.render(t, 'en'), throwsArgumentError);
    });

    test('translatable requires languageName', () async {
      final t = dynamicText(
          'x', 'Status: {status}', {'status': ParamKind.translatable});
      expect(
        () => r.render(t, 'ne-NP', args: {'status': 'approved'}),
        throwsArgumentError,
      );
    });

    test('date param', () async {
      final t =
          dynamicText('deadline', 'Post by {date}', {'date': ParamKind.date});
      final result = await r.render(t, 'en', args: {'date': '2025-02-15'});
      expect(result, contains('2025'));
    });

    test('currency param', () async {
      final t = dynamicText('price', 'Costs {amount}', {
        'amount':
            const Param('amount', kind: ParamKind.currency, currency: 'NPR'),
      });
      final result = await r.render(t, 'ne-NP', args: {'amount': 2500});
      expect(result, anyOf(contains('2,500'), contains('२,५००')));
    });

    test('userAdapted English passthrough', () async {
      final t =
          dynamicText('note', 'Note: {note}', {'note': ParamKind.userAdapted});
      final result = await r.render(t, 'en', args: {'note': 'Ends Feb 15'});
      expect(result, 'Note: Ends Feb 15');
    });

    // ── plural ──────────────────────────────────────────────────────────────

    test('English plural singular', () async {
      final t = pluralText('campaign_count', 'You have {count} campaign',
          'You have {count} campaigns');
      expect(
          await r.render(t, 'en', args: {'count': 1}), 'You have 1 campaign');
    });

    test('English plural plural', () async {
      final t = pluralText('campaign_count', 'You have {count} campaign',
          'You have {count} campaigns');
      expect(
          await r.render(t, 'en', args: {'count': 5}), 'You have 5 campaigns');
    });

    test('Nepali plural singular', () async {
      final t = pluralText('campaign_count', 'You have {count} campaign',
          'You have {count} campaigns');
      final result = await r.render(t, 'ne-NP', args: {'count': 1});
      expect(result, contains('छ'));
      expect(result, contains('१'));
    });

    test('Nepali plural plural', () async {
      final t = pluralText('campaign_count', 'You have {count} campaign',
          'You have {count} campaigns');
      final result = await r.render(t, 'ne-NP', args: {'count': 5});
      expect(result, contains('छन्'));
      expect(result, contains('५'));
    });

    test('compiled plural may omit count placeholder', () async {
      final tempDir = Directory.systemTemp.createTempSync('stringlocale_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final prompt = ((body['messages'] as List).first
            as Map<String, dynamic>)['content'] as String;

        expect(prompt, contains('Singular form: You have {count} campaign'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'singular': 'لديك حملة واحدة',
                    'plural': 'لديك {count} حملات',
                    'rule': 'count == 1',
                    'rule_explanation': 'Use singular only when count is one.'
                  })
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final t = pluralText('campaign_count', 'You have {count} campaign',
          'You have {count} campaigns');

      await compileLocales(
        texts: [t],
        locales: ['ar-SA:Arabic'],
        localeDir: tempDir.path,
        apiKey: 'test-key',
        client: client,
      );

      final renderer = Renderer(
        localeData: {
          'ar-SA': jsonDecode(
            File('${tempDir.path}/ar-SA.json').readAsStringSync(),
          ) as Map<String, dynamic>,
        },
      );

      expect(
        await renderer.render(t, 'ar-SA', args: {'count': 1}),
        'لديك حملة واحدة',
      );
      expect(
        await renderer.render(t, 'ar-SA', args: {'count': 5}),
        'لديك ٥ حملات',
      );
    });
  });

  group('Flutter widgets', () {
    testWidgets('StringLocaleScope reflects parent locale updates',
        (tester) async {
      final renderer = Renderer(
        localeData: {
          'ne-NP': {
            'welcome': {'text': 'stringlocale मा स्वागत छ', 'src_hash': 'a'},
          },
        },
      );
      final t = staticText('welcome', 'Welcome to stringlocale');

      Widget buildScope(String localeCode, String languageName) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: StringLocaleScope(
            localeCode: localeCode,
            languageName: languageName,
            renderer: renderer,
            child: Tr(t),
          ),
        );
      }

      await tester.pumpWidget(buildScope('en', 'English'));
      await tester.pump();
      expect(find.text('Welcome to stringlocale'), findsOneWidget);

      await tester.pumpWidget(buildScope('ne-NP', 'Nepali'));
      await tester.pump();
      expect(find.text('stringlocale मा स्वागत छ'), findsOneWidget);
    });
  });

  // ── overrides ───────────────────────────────────────────────────────────────

  group('Overrides', () {
    test('override wins over compiled', () async {
      final r = Renderer(
        localeData: {
          'ne-NP': {
            'welcome': {'text': 'auto', 'src_hash': 'x'}
          }
        },
        overrides: {
          'ne-NP': {
            'welcome': {'text': 'manual', 'src_hash': 'x'}
          }
        },
      );
      final t = staticText('welcome', 'Welcome');
      expect(await r.render(t, 'ne-NP'), 'manual');
    });

    test('setOverrides applies at runtime', () async {
      final r = Renderer(
        localeData: {
          'ne-NP': {
            'welcome': {'text': 'auto', 'src_hash': 'x'}
          }
        },
      );
      r.setOverrides('ne-NP', {
        'welcome': {'text': 'late', 'src_hash': 'x'}
      });
      final t = staticText('welcome', 'Welcome');
      expect(await r.render(t, 'ne-NP'), 'late');
    });
  });
}
