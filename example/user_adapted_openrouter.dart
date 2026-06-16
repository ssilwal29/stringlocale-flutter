/// OpenRouter-backed runtime adapter example for Param.userAdapted.
///
/// Run from package root:
///   export OPENROUTER_API_KEY=...your key...
///   dart run example/user_adapted_openrouter.dart
///
/// What this shows:
/// 1) You mark specific params with Param.userAdapted(context: ...).
/// 2) You pass an adapter into load(..., adapter: ...).
/// 3) The adapter receives (value, locale, context) and returns rewritten text.
/// 4) If adapter is missing, values pass through unchanged.
import 'dart:convert';
import 'dart:io';

import 'package:stringlocale/compile.dart';
import 'package:stringlocale/stringlocale.dart';

import 'sample_strings.dart';

const String _outDir = '.dart_tool/stringlocale_user_adapted_openrouter';
const String _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
const String _model = 'google/gemini-2.5-flash';

Future<void> main() async {
  final apiKey = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln('OPENROUTER_API_KEY is required for this example.');
    exitCode = 64;
    return;
  }

  sampleRegisterAll();

  final result = await compileStrings(
    strings: sampleStrings,
    locales: const ['en-US', 'ne-NP'],
    sourceLocale: 'en-US',
    drafter: OfflineDrafter(),
    existingDir: _outDir,
  );
  result.writeSplit(_outDir);

  final bundle = load(
    _outDir,
    locale: 'ne-NP',
    userAdaptedMode: UserAdaptedMode.realtime,
    adapter: (value, locale, context) => _openRouterAdapt(
      apiKey: apiKey,
      value: value,
      locale: locale,
      context: context,
    ),
  );

  useBundle(bundle, locale: 'ne-NP');

  print('profile_bio: ${profileBio.resolve(args: {
        'bio': '1200 followers, vintage camera collector, ships on Fridays'
      })}');
  print('delivery_note: ${deliveryNote.resolve(args: {
        'note':
            'Preorder ships in 7 business days. Tracking links update nightly.'
      })}');
  print('moderation_reason: ${moderationReason.resolve(args: {
        'reason':
            'Contains all required legal details but reads too formal for marketplace shoppers.'
      })}');
}

String _escapeJsonString(String value) => jsonEncode(value);

String _openRouterAdapt({
  required String apiKey,
  required String value,
  required String locale,
  required String? context,
}) {
  final prompt = '''
Rewrite this user text for locale "$locale".
Keep all concrete facts unchanged (numbers, names, dates, product claims).
Do not add new facts. Keep it concise.
${context == null ? '' : 'Context: $context'}

Text: $value
Return only the rewritten text.
''';

  final body = '{'
      '"model":"$_model",'
      '"messages":[{"role":"user","content":${_escapeJsonString(prompt)}}],'
      '"max_tokens":256,'
      '"temperature":0.2'
      '}';

  final result = Process.runSync(
    'curl',
    [
      '-sS',
      '--max-time',
      '45',
      '-X',
      'POST',
      _openRouterUrl,
      '-H',
      'Authorization: Bearer $apiKey',
      '-H',
      'Content-Type: application/json',
      '-H',
      'HTTP-Referer: https://github.com/ssilwal29/stringlocale-flutter',
      '-H',
      'X-Title: stringlocale userAdapted example',
      '-d',
      body,
    ],
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'curl',
      const [],
      (result.stderr ?? '').toString(),
      result.exitCode,
    );
  }

  final responseBody = result.stdout.toString();
  final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw StateError('OpenRouter error: ${decoded['error']}');
  }
  final content = (((decoded['choices'] as List?)?.first as Map?)?['message']
      as Map?)?['content'];
  final out = content?.toString().trim();
  if (out == null || out.isEmpty) {
    throw StateError('OpenRouter returned empty adapter output.');
  }
  return out;
}
