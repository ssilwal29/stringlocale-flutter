import 'package:http/http.dart' as http;

import 'compiler_web.dart' if (dart.library.io) 'compiler_io.dart' as impl;
import 'llm.dart';
import 'text.dart';

/// Compile translation JSON files for all given locales.
///
/// On Dart VM / Flutter native, this writes JSON files under [localeDir]. On
/// Web, this throws [UnsupportedError] because browsers cannot write project
/// files; run locale compilation as a build-time Dart command instead.
///
/// [locales] entries are `code:Language` (for example `ne-NP:Nepali`) or just
/// `code`. Unchanged source strings are skipped unless [force] is true.
Future<Map<String, Map<String, String>>> compileLocales({
  required List<Message> texts,
  required List<String> locales,
  String localeDir = 'locales',
  String model = defaultModel,
  String? apiKey,
  bool force = false,
  http.Client? client,
}) =>
    impl.compileLocales(
      texts: texts,
      locales: locales,
      localeDir: localeDir,
      model: model,
      apiKey: apiKey,
      force: force,
      client: client,
    );
