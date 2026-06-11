// Run with: dart run example/compile.dart
// Requires OPENROUTER_API_KEY in the environment.
import 'package:stringlocale/stringlocale.dart';

import 'texts.dart';

Future<void> main() async {
  await compileLocales(
    texts: texts,
    locales: [
      'ne-NP:Nepali',
      'ja-JP:Japanese',
      'ar-SA:Arabic',
    ],
    localeDir: 'locales',
  );
}
