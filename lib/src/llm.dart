import 'dart:convert';
import 'package:http/http.dart' as http;

import 'env_web.dart' if (dart.library.io) 'env_io.dart';

/// Default OpenRouter model used for compile-time and runtime LLM calls.
const String defaultModel = 'google/gemini-2.5-flash';
const String _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

String _getApiKey(String? apiKey) {
  final key = apiKey ?? readEnv('OPENROUTER_API_KEY') ?? '';
  if (key.isEmpty) {
    throw StateError(
      'OPENROUTER_API_KEY is not set. Get a key at https://openrouter.ai/keys',
    );
  }
  return key;
}

/// Low-level OpenRouter call. Returns the raw assistant message content.
Future<String> callOpenRouter(
  String prompt, {
  String model = defaultModel,
  String? apiKey,
  http.Client? client,
}) async {
  final key = _getApiKey(apiKey);
  final httpClient = client ?? http.Client();

  try {
    final res = await httpClient.post(
      Uri.parse(_openRouterUrl),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/ssilwal29/stringlocale-flutter.git',
        'X-Title': 'stringlocale',
      },
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
      throw Exception(
        'OpenRouter API error ${res.statusCode}: ${res.body}',
      );
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = (data['choices'][0]['message']['content'] as String).trim();
    return content;
  } finally {
    if (client == null) httpClient.close();
  }
}

/// Compile-time: translate a UI string (placeholders preserved).
Future<String> translateString(
  String source,
  String localeCode,
  String languageName, {
  String model = defaultModel,
  String? apiKey,
  http.Client? client,
}) {
  final prompt = '''
Translate this UI string for a mobile/web app.

Target locale: $localeCode
Target language: $languageName
Source text: $source

Rules:
- Return ONLY the translated string, nothing else.
- Preserve placeholders EXACTLY as-is: {count}, {date}, {amount}, etc.
- Do NOT translate placeholder names inside curly braces.
- Keep brand names unchanged.
- Use natural, concise app UI language.
- Do not add quotes around the result.''';

  return callOpenRouter(prompt, model: model, apiKey: apiKey, client: client);
}

/// Result of a plural translation: both forms plus the selection rule.
class PluralTranslation {
  /// Create a translated plural result.
  PluralTranslation({
    required this.singular,
    required this.plural,
    required this.rule,
    required this.ruleExplanation,
  });

  /// Translated singular-form template.
  final String singular;

  /// Translated plural-form template.
  final String plural;

  /// Boolean expression that returns true when [singular] should be used.
  final String rule;

  /// Human-readable explanation of [rule], usually returned by the LLM.
  final String ruleExplanation;

  /// Parse a [PluralTranslation] from OpenRouter JSON response content.
  factory PluralTranslation.fromJson(Map<String, dynamic> j) =>
      PluralTranslation(
        singular: j['singular'] as String,
        plural: j['plural'] as String,
        rule: j['rule'] as String,
        ruleExplanation: (j['rule_explanation'] as String?) ?? '',
      );
}

/// Compile-time: translate both plural forms and generate the plural rule.
Future<PluralTranslation> translatePlural(
  String singular,
  String pluralForm,
  String localeCode,
  String languageName,
  String countParam, {
  String model = defaultModel,
  String? apiKey,
  http.Client? client,
}) async {
  final prompt = '''
Translate these two UI string forms and provide the plural selection rule.

Target locale: $localeCode
Target language: $languageName
Count parameter name: $countParam

Singular form: $singular
Plural form: $pluralForm

Rules for translation:
- Preserve placeholders EXACTLY as-is: {$countParam}, {date}, {amount}, etc.
- Do NOT translate placeholder names inside curly braces.
- Keep brand names unchanged.
- Use natural, concise app UI language.

Rules for the plural rule:
- Write a boolean expression using only the variable "$countParam".
- The expression should return true when the SINGULAR form should be used.
- Use only: comparison operators (<, >, ==, !=, <=, >=), arithmetic (%, *, +, -), && || !, integers.
- Examples: "$countParam < 2", "$countParam == 1", "$countParam % 10 == 1 && $countParam % 100 != 11"

Respond with ONLY a JSON object, no markdown, no explanation:
{
  "singular": "<translated singular>",
  "plural": "<translated plural>",
  "rule": "<boolean expression — true means use singular>",
  "rule_explanation": "<one sentence in English>"
}''';

  var raw = await callOpenRouter(prompt,
      model: model, apiKey: apiKey, client: client);
  raw = raw.trim();
  if (raw.startsWith('```')) {
    final firstNl = raw.indexOf('\n');
    raw = raw.substring(firstNl + 1);
    final lastFence = raw.lastIndexOf('```');
    if (lastFence != -1) raw = raw.substring(0, lastFence);
  }
  return PluralTranslation.fromJson(
      jsonDecode(raw.trim()) as Map<String, dynamic>);
}

/// Runtime: translate a single short label value (status, category, etc.).
Future<String> translateValue(
  String value,
  String localeCode,
  String languageName, {
  String? context,
  String model = defaultModel,
  String? apiKey,
  http.Client? client,
}) {
  final contextLine = context != null ? 'Context: $context\n' : '';
  final prompt = '''
Translate this UI label value for a mobile/web app.

Target locale: $localeCode
Target language: $languageName
${contextLine}Value: $value

Rules:
- Return ONLY the translated string, nothing else.
- This is a short UI label (status, category, type, etc.).
- Use natural app language.
- Do not add quotes around the result.''';

  return callOpenRouter(prompt, model: model, apiKey: apiKey, client: client);
}

/// Runtime: adapt free prose — only reformat dates/numbers/currency to the
/// target locale, leave all prose untranslated.
Future<String> adaptFreeText(
  String value,
  String localeCode,
  String languageName, {
  String? context,
  String model = defaultModel,
  String? apiKey,
  http.Client? client,
}) {
  final contextLine = context != null ? 'Context: $context\n' : '';
  final prompt = '''
You are a locale formatter, NOT a translator.

Target locale: $localeCode
Target language: $languageName
$contextLine
Given the text below, find ONLY: dates, numbers, currency amounts, and percentages.
Convert each to the format and digits natural for the target locale.
Do NOT translate any words. Do NOT change any prose. Do NOT rephrase anything.
Leave every word exactly as written — only reformat numeric/date/currency tokens.

Return ONLY the adapted text, nothing else.

Text:
$value''';

  return callOpenRouter(prompt, model: model, apiKey: apiKey, client: client);
}
