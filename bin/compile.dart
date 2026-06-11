import 'dart:io';

/// CLI: `dart run stringlocale:compile --help`
///
/// Because Dart can't dynamically import an arbitrary user file by path the way
/// Node/Python can, the recommended pattern is to write a tiny compile script
/// in your own project that calls [compileLocales] directly with your TEXTS
/// list. See example/compile.dart.
///
/// This entry point prints setup guidance. It does not auto-discover a user's
/// message definitions after `dart pub add` or `flutter pub add`.
Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);

  if (opts.containsKey('help') || args.isEmpty) {
    stdout.writeln('''
stringlocale — compile LLM-generated locale files

After installing with `dart pub add stringlocale` or `flutter pub add stringlocale`,
you can run this help command with:

  dart run stringlocale:compile --help

Dart packages cannot dynamically import your app's `texts.dart` by path, so the
recommended usage is to write a small script in your project, e.g. compile.dart:

  import 'texts.dart';
  import 'package:stringlocale/stringlocale.dart';

  void main() async {
    await compileLocales(
      texts: texts,
      locales: ['ne-NP:Nepali', 'ja-JP:Japanese'],
    );
  }

Then run:  dart run compile.dart

This is the idiomatic Dart approach: your script imports your typed messages and
passes them to compileLocales().
Set OPENROUTER_API_KEY in your environment first.
''');
    exit(0);
  }

  stderr.writeln(
    'Direct CLI text loading is not supported in Dart. '
    'Write a compile.dart script that imports your TEXTS and calls '
    'compileLocales(). Run with --help for the template.',
  );
  exit(1);
}

Map<String, dynamic> _parseArgs(List<String> args) {
  final map = <String, dynamic>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--')) {
      final key = a.substring(2);
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        map[key] = args[++i];
      } else {
        map[key] = true;
      }
    }
  }
  return map;
}
