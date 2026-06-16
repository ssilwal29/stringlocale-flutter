/// Default OpenRouter-backed adapter for userAdapted params on IO platforms.

library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String defaultUserAdaptedModel = 'google/gemini-2.5-flash';
const String _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

// Compile-time values from `--dart-define`. Flutter GUI apps don't inherit the
// shell environment, so `--dart-define` is the reliable way to pass these; they
// are only readable via String.fromEnvironment, not Platform.environment.
const String _apiKeyFromDefine = String.fromEnvironment('OPENROUTER_API_KEY');
const String _modelFromDefine = String.fromEnvironment('OPENROUTER_MODEL');

/// Reads [name] from the OS environment first, falling back to the
/// `--dart-define` compile-time value.
String _readConfig(String name, String fromDefine) {
  final fromEnv = Platform.environment[name] ?? '';
  return fromEnv.isNotEmpty ? fromEnv : fromDefine;
}

String Function(String value, String locale, String? context)?
    defaultAdapter() {
  // Sync path keeps backwards compatibility but does not perform network calls.
  // Use defaultAsyncAdapter + resolveAsync / AsyncTr for HTTP OpenRouter calls.
  return null;
}

Future<String> Function(String value, String locale, String? context)?
    defaultAsyncAdapter() {
  final apiKey = _readConfig('OPENROUTER_API_KEY', _apiKeyFromDefine);
  if (apiKey.isEmpty) return null;
  final modelConfig = _readConfig('OPENROUTER_MODEL', _modelFromDefine);
  final model = modelConfig.isNotEmpty ? modelConfig : defaultUserAdaptedModel;
  final client = http.Client();
  return (value, locale, context) => _adapt(
        client: client,
        apiKey: apiKey,
        model: model,
        value: value,
        locale: locale,
        context: context,
      );
}

Future<String> _adapt({
  required http.Client client,
  required String apiKey,
  required String model,
  required String value,
  required String locale,
  required String? context,
}) async {
  final prompt = '''
Rewrite this user text for locale "$locale".
Keep all concrete facts unchanged (numbers, names, dates, product claims).
Do not add new facts. Keep it concise.
${context == null ? '' : 'Context: $context'}

Text: $value
Return only the rewritten text.
''';

  final response = await client
      .post(
        Uri.parse(_openRouterUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/ssilwal29/stringlocale-flutter',
          'X-Title': 'stringlocale userAdapted default',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 256,
          'temperature': 0.2,
        }),
      )
      .timeout(const Duration(seconds: 45));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
        'OpenRouter error ${response.statusCode}: ${response.body}');
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final content = (((decoded['choices'] as List?)?.first as Map?)?['message']
      as Map?)?['content'];
  final out = content?.toString().trim();
  if (out == null || out.isEmpty) {
    throw StateError('OpenRouter returned empty adapter output.');
  }
  return out;
}
