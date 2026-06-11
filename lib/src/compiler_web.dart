import 'package:http/http.dart' as http;

import 'llm.dart';
import 'text.dart';

Future<Map<String, Map<String, String>>> compileLocales({
  required List<Message> texts,
  required List<String> locales,
  String localeDir = 'locales',
  String model = defaultModel,
  String? apiKey,
  bool force = false,
  http.Client? client,
}) {
  throw UnsupportedError(
    'compileLocales() is a build-time filesystem command and is not supported '
    'in browser runtimes. Run it with `dart run compile.dart`, then load the '
    'generated JSON into Renderer(localeData: ...).',
  );
}
