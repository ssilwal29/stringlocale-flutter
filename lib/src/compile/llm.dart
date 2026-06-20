/// Drafters generate per-cell strings at compile time.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String defaultModel = 'google/gemini-2.5-flash';

/// Default endpoint (OpenRouter). Any OpenAI-compatible
/// `/chat/completions` endpoint works — see [LlmDrafter].
const String defaultBaseUrl = 'https://openrouter.ai/api/v1/chat/completions';

abstract class Drafter {
  String draftTemplate(String baseText, String locale, String language,
      String axisDesc, Set<String> placeholders);
  String draftEnum(
      String value, String locale, String language, String? context);
}

/// Deterministic, no-network drafter — builds a testable bundle without a key.
class OfflineDrafter implements Drafter {
  @override
  String draftTemplate(String baseText, String locale, String language,
      String axisDesc, Set<String> placeholders) {
    final lang = locale.split('-')[0];
    if (lang == 'en') return baseText;
    final suffix = axisDesc.isNotEmpty ? ' [$axisDesc]' : '';
    return '$lang:$baseText$suffix';
  }

  @override
  String draftEnum(
      String value, String locale, String language, String? context) {
    final lang = locale.split('-')[0];
    return lang == 'en' ? value : '$lang:$value';
  }
}

/// LLM-backed drafter for any OpenAI-compatible `/chat/completions` API
/// (OpenRouter, OpenAI, Groq, Together, a local Ollama/LM Studio server, etc.).
///
/// Configure the endpoint and credentials via constructor arguments or
/// environment variables:
/// - `baseUrl`  → `STRINGLOCALE_BASE_URL` (falls back to OpenRouter)
/// - `apiKey`   → `STRINGLOCALE_API_KEY` then `OPENROUTER_API_KEY`
///
/// Note: Dart HTTP is async; the compiler awaits these, so this exposes async
/// variants. The [Drafter] interface stays sync for the offline path; the
/// async LLM calls are used by the async compiler entry points.
class LlmDrafter {
  LlmDrafter({
    this.model = defaultModel,
    this.apiKey,
    this.baseUrl,
    Map<String, String>? headers,
    http.Client? client,
  })  : _extraHeaders = headers,
        _client = client ?? http.Client();

  final String model;
  final String? apiKey;

  /// Endpoint URL. When null, resolved from `STRINGLOCALE_BASE_URL` /
  /// `OPENROUTER_BASE_URL`, defaulting to [defaultBaseUrl].
  final String? baseUrl;

  final Map<String, String>? _extraHeaders;
  final http.Client _client;

  String _resolveBaseUrl() {
    if (baseUrl != null && baseUrl!.isNotEmpty) return baseUrl!;
    final env = Platform.environment['STRINGLOCALE_BASE_URL'] ??
        Platform.environment['OPENROUTER_BASE_URL'] ??
        '';
    return env.isNotEmpty ? env : defaultBaseUrl;
  }

  String _key() {
    final k = apiKey ??
        Platform.environment['STRINGLOCALE_API_KEY'] ??
        Platform.environment['OPENROUTER_API_KEY'] ??
        '';
    if (k.isEmpty) {
      throw StateError(
          'No LLM API key set. Provide apiKey or set STRINGLOCALE_API_KEY '
          '(or OPENROUTER_API_KEY).');
    }
    return k;
  }

  Map<String, String> _headers() => {
        'Authorization': 'Bearer ${_key()}',
        'Content-Type': 'application/json',
        ...?_extraHeaders,
      };

  Future<String> _call(String prompt) async {
    final res = await _client.post(
      Uri.parse(_resolveBaseUrl()),
      headers: _headers(),
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 512,
        'temperature': 0.1,
      }),
    );
    if (res.statusCode != 200) {
      throw HttpException('LLM API error ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['choices'][0]['message']['content'] as String).trim();
  }

  Future<String> draftTemplate(String baseText, String locale, String language,
      String axisDesc, Set<String> placeholders) {
    final ph = placeholders.isEmpty
        ? '(none)'
        : (placeholders.toList()..sort()).map((p) => '{$p}').join(', ');
    final axisLine =
        axisDesc.isNotEmpty ? 'Variant to produce: $axisDesc\n' : '';
    final prompt = '''Produce one UI string for a mobile/web app.

Target locale: $locale
Target language: $language
Base English text: $baseText
Placeholders that MUST be preserved exactly: $ph
$axisLine
Rules:
- Return ONLY the final string, nothing else.
- Preserve every placeholder exactly, e.g. {count}, {name}.
- Word the sentence naturally for the given variant (gender / plural form).
- Keep brand names unchanged. Do not add quotes.''';
    return _call(prompt);
  }

  Future<String> draftEnum(
      String value, String locale, String language, String? context) {
    final ctx = context != null ? 'Context: $context\n' : '';
    final prompt = '''Translate this short UI label value.

Target locale: $locale
Target language: $language
${ctx}Value: $value

Rules:
- Return ONLY the translated label, nothing else.
- It is a short enum-like label (status/category/type).
- Use natural app language. No quotes.''';
    return _call(prompt);
  }

  void close() => _client.close();
}

/// OpenRouter-flavored [LlmDrafter]: defaults the endpoint to OpenRouter and
/// sends OpenRouter's optional attribution headers. Kept for backward
/// compatibility — [LlmDrafter] works with any OpenAI-compatible API.
class OpenRouterDrafter extends LlmDrafter {
  OpenRouterDrafter({super.model, super.apiKey, super.client})
      : super(
          baseUrl: defaultBaseUrl,
          headers: const {
            'HTTP-Referer': 'https://github.com/stringlocale/stringlocale',
            'X-Title': 'stringlocale',
          },
        );
}
