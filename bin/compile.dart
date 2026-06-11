import 'dart:io';

/// CLI: `dart run stringlocale:compile --help`
///
/// Because Dart can't dynamically import an arbitrary user file by path the way
/// Node/Python can, the recommended pattern is to write a tiny compile script
/// in your own project that calls [compileLocales] directly with your TEXTS
/// list. See example/compile.dart.
///
/// This entry point can scaffold that script with `--init`. It does not
/// auto-discover a user's message definitions after `dart pub add` or
/// `flutter pub add`.
Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);

  if (opts.containsKey('init')) {
    _initCompileScript(force: opts.containsKey('force'));
    exit(0);
  }

  if (opts.containsKey('help') || args.isEmpty) {
    stdout.writeln('''
stringlocale — compile LLM-generated locale files

After installing with `dart pub add stringlocale` or `flutter pub add stringlocale`,
you can run this help command with:

  dart run stringlocale:compile --help

Create a project-local compile script with:

  dart run stringlocale:compile --init

This creates: tool/compile_locales.dart

Dart packages cannot dynamically import your app's `texts.dart` by path, so the
recommended usage is to run or edit the generated script:

  import 'package:stringlocale/stringlocale.dart';
  import '../lib/texts.dart';

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

Then run:  dart run tool/compile_locales.dart

This is the idiomatic Dart approach: your script imports your typed messages and
passes them to compileLocales().
Set OPENROUTER_API_KEY in your environment first.
''');
    exit(0);
  }

  stderr.writeln(
    'Direct CLI text loading is not supported in Dart. '
    'Run with --init to create tool/compile_locales.dart, then edit it to '
    'import your message list and call compileLocales().',
  );
  exit(1);
}

void _initCompileScript({required bool force}) {
  final toolDir = Directory('tool');
  final outFile = File('tool/compile_locales.dart');

  if (outFile.existsSync() && !force) {
    stderr.writeln(
      'tool/compile_locales.dart already exists. '
      'Run with --init --force to overwrite it.',
    );
    exit(1);
  }

  toolDir.createSync(recursive: true);
  outFile.writeAsStringSync(_compileScriptTemplate);

  stdout.writeln('Created tool/compile_locales.dart');
  stdout.writeln('Edit the locales list if needed, then run:');
  stdout.writeln('  dart run tool/compile_locales.dart');
}

const String _compileScriptTemplate =
    '''import 'package:stringlocale/stringlocale.dart';
import '../lib/texts.dart';

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
''';

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
