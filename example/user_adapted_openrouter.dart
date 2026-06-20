/// LLM-backed runtime adapter example for Param.userAdapted.
///
/// Works with any OpenAI-compatible /chat/completions endpoint (OpenRouter,
/// OpenAI, Groq, Together, a local Ollama/LM Studio server, etc.).
///
/// Run from package root:
///   export STRINGLOCALE_API_KEY=...your key...
///   # optional overrides:
///   #   export STRINGLOCALE_BASE_URL=https://api.openai.com/v1/chat/completions
///   #   export STRINGLOCALE_MODEL=gpt-4o-mini
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
const String _defaultBaseUrl =
    'https://openrouter.ai/api/v1/chat/completions';
const String _defaultModel = 'google/gemini-2.5-flash';

String _env(List<String> names, [String fallback = '']) {
  for (final name in names) {
    final value = Platform.environment[name] ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

Future<void> main() async {
  final apiKey = _env(['STRINGLOCALE_API_KEY', 'OPENROUTER_API_KEY']);
  if (apiKey.isEmpty) {
    stderr.writeln('STRINGLOCALE_API_KEY (or OPENROUTER_API_KEY) is required '
        'for this example.');
    exitCode = 64;
    return;
  }
  final baseUrl =
      _env(['STRINGLOCALE_BASE_URL', 'OPENROUTER_BASE_URL'], _defaultBaseUrl);
  final model = _env(['STRINGLOCALE_MODEL', 'OPENROUTER_MODEL'], _defaultModel);

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
    adapter: (value, locale, context) => _llmAdapt(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
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

String _llmAdapt({
  required String apiKey,
  required String baseUrl,
  required String model,
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
      '"model":"$model",'
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
      baseUrl,
      '-H',
      'Authorization: Bearer $apiKey',
      '-H',
      'Content-Type: application/json',
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
