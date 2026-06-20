import 'dart:convert';
import 'dart:io';

import 'package:stringlocale/compile.dart' show defaultModel, defaultBaseUrl;

const _defaultInput = 'lib/strings.dart';
const _defaultOut = 'dist';
const _defaultRegister = 'registerAll';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    _printHelp();
    return;
  }

  final command = args.first;
  final options = _Options.parse(args.skip(1).toList());

  try {
    switch (command) {
      case 'compile':
        await _compile(options);
        break;
      case 'check':
        await _check(options);
        break;
      case 'prune':
        await _prune(options);
        break;
      default:
        _fail("Unknown command '$command'.\n");
    }
  } on _CliException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
  }
}

Future<void> _compile(_Options options) async {
  final locales = _locales(options, required: true)!;
  final out = options.value('out') ?? _defaultOut;
  final sourceLocale = options.value('source-locale') ?? 'en';
  final mode = options.value('drafter') ?? 'auto';
  final model = options.value('model');
  final baseUrl = options.value('base-url');
  final quiet = options.flag('quiet');
  if (!['auto', 'offline', 'llm', 'openrouter'].contains(mode)) {
    throw _CliException(
        "--drafter must be one of: auto, offline, llm, openrouter");
  }
  if (mode == 'offline' && model != null) {
    throw _CliException(
        '--model can only be used with --drafter llm, openrouter, or auto.');
  }
  if (mode == 'offline' && baseUrl != null) {
    throw _CliException(
        '--base-url can only be used with --drafter llm, openrouter, or auto.');
  }

  final combined = options.value('combined');
  final script = _runnerScript(options, '''
  final drafter = ${_drafterExpression(mode, model, baseUrl)};
  final stringCount = getRegistry().length;
  ${quiet ? '' : "print('stringlocale: compiling \$stringCount strings for ${locales.length} locales...');"}
  ${quiet ? '' : "print('stringlocale: locales: ${locales.join(', ')}');"}
  ${quiet ? '' : "print('stringlocale: drafter: ${mode == 'auto' ? 'auto' : mode}');"}
  ${quiet || model == null ? '' : "print('stringlocale: model: $model');"}
  final result = await compileAll(
    locales: ${_dartStringList(locales)},
    drafter: drafter,
    sourceLocale: ${jsonEncode(sourceLocale)},
    force: ${options.flag('force')},
    existingDir: ${jsonEncode(out)},
    log: ${quiet ? 'null' : "(message) => print('stringlocale: compiling \$message')"},
  );
  ${combined == null ? 'result.writeSplit(${jsonEncode(out)});' : 'result.writeCombined(${jsonEncode(combined)});'}
  print('stringlocale: wrote \${result.cellCount()} cells to ${combined ?? out}.');
''');
  await _runScript(script);
}

Future<void> _check(_Options options) async {
  final out = options.value('out') ?? _defaultOut;
  final locales = _locales(options, required: false);
  final script = _runnerScript(options, '''
  final report = check(
    null,
    ${jsonEncode(out)},
    locales: ${locales == null ? 'null' : _dartStringList(locales)},
  );
  print(report.summary());
  if (!report.ok) exitCode = 1;
''');
  await _runScript(script);
}

Future<void> _prune(_Options options) async {
  final out = options.value('out') ?? _defaultOut;
  final locales = _locales(options, required: false);
  final script = _runnerScript(options, '''
  final result = prune(
    null,
    ${jsonEncode(out)},
    locales: ${locales == null ? 'null' : _dartStringList(locales)},
    dryRun: ${options.flag('dry-run')},
  );
  print(result.summary());
''');
  await _runScript(script);
}

String _runnerScript(_Options options, String body) {
  final input = options.value('input') ?? _defaultInput;
  final register = options.value('register') ?? _defaultRegister;
  final skipRegister = options.flag('no-register');
  if (skipRegister && options.has('register')) {
    throw _CliException('Use either --register or --no-register, not both.');
  }

  return '''
import 'dart:io';

import 'package:stringlocale/compile.dart';
import 'package:stringlocale/stringlocale.dart';
import ${jsonEncode(_importUri(input))} as strings;

Future<void> main() async {
  ${skipRegister ? '' : 'strings.$register();'}
$body
}
''';
}

String _drafterExpression(String mode, String? model, String? baseUrl) {
  final args = [
    if (model != null) 'model: ${jsonEncode(model)}',
    if (baseUrl != null) 'baseUrl: ${jsonEncode(baseUrl)}',
  ].join(', ');
  switch (mode) {
    case 'offline':
      return 'OfflineDrafter()';
    case 'openrouter':
      return 'OpenRouterDrafter($args)';
    case 'llm':
      return 'LlmDrafter($args)';
    default:
      return "(Platform.environment.containsKey('STRINGLOCALE_API_KEY') || Platform.environment.containsKey('OPENROUTER_API_KEY')) ? LlmDrafter($args) : OfflineDrafter()";
  }
}

List<String>? _locales(_Options options, {required bool required}) {
  final value = options.value('locales');
  if (value == null || value.trim().isEmpty) {
    if (required) {
      throw _CliException('Missing required --locales option.');
    }
    return null;
  }
  final locales = value
      .split(',')
      .map((locale) => locale.trim())
      .where((locale) => locale.isNotEmpty)
      .toList();
  if (locales.isEmpty && required) {
    throw _CliException('Missing required --locales option.');
  }
  return locales;
}

String _importUri(String input) {
  if (input.startsWith('package:') || input.startsWith('dart:')) return input;
  final file = File(input);
  if (!file.existsSync()) {
    throw _CliException("Input file not found: $input");
  }
  return file.absolute.uri.toString();
}

String _dartStringList(List<String> values) =>
    '[${values.map(jsonEncode).join(', ')}]';

Future<void> _runScript(String content) async {
  final dir = Directory('.dart_tool/stringlocale');
  dir.createSync(recursive: true);
  final file = File('${dir.path}/runner.dart');
  file.writeAsStringSync(content);

  final process = await Process.start(
    Platform.resolvedExecutable,
    ['run', file.path],
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) exitCode = code;
}

void _printHelp() {
  stdout.write('''
stringlocale command line tools

Usage:
  dart run stringlocale compile --locales en,ne-NP,ja-JP [options]
  dart run stringlocale check [options]
  dart run stringlocale prune [options]

Commands:
  compile   Compile registered StringLocale declarations into bundle files.
  check     Check a compiled bundle for missing, stale, orphaned, or bad cells.
  prune     Remove orphaned compiled strings from a bundle.

Options:
  --input <path>          Dart file that declares strings. Default: $_defaultInput
  --register <name>      Registration function to call. Default: $_defaultRegister
  --no-register          Import the input file but do not call a register function.
  --locales <codes>      Comma-separated locale list, e.g. en,ne-NP,ja-JP.
  --out <dir>            Bundle directory. Default: $_defaultOut
  --combined <path>      For compile, write one combined bundle instead of split files.
  --source-locale <code> Source locale for compile. Default: en
  --drafter <mode>       auto, offline, llm, or openrouter. Default: auto
  --model <id>           LLM model id. Default: $defaultModel
  --base-url <url>       OpenAI-compatible chat-completions endpoint.
                         Default: $defaultBaseUrl
  --force                Re-draft cells even when incremental hashes match.
  --dry-run              For prune, report removals without writing files.
  --quiet                For compile, hide progress messages except final output.

Examples:
  dart run stringlocale compile --locales en,ne-NP --out dist
  dart run stringlocale check --out dist
  dart run stringlocale prune --out dist --dry-run
  dart run stringlocale compile --input example/sample_strings.dart --register sampleRegisterAll --locales en,ne-NP
''');
}

Never _fail(String message) {
  _printHelp();
  throw _CliException(message);
}

class _Options {
  _Options(this._values, this._flags);

  final Map<String, String> _values;
  final Set<String> _flags;

  static const _valueOptions = {
    'input',
    'register',
    'locales',
    'out',
    'combined',
    'source-locale',
    'drafter',
    'model',
    'base-url',
  };

  static const _flagOptions = {
    'no-register',
    'force',
    'dry-run',
    'quiet',
  };

  static _Options parse(List<String> args) {
    final values = <String, String>{};
    final flags = <String>{};

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (!arg.startsWith('--')) {
        throw _CliException("Unexpected argument: $arg");
      }
      final raw = arg.substring(2);
      final split = raw.split('=');
      final name = split.first;
      if (_valueOptions.contains(name)) {
        if (split.length > 1) {
          values[name] = split.skip(1).join('=');
        } else {
          if (i + 1 >= args.length) {
            throw _CliException('Missing value for --$name.');
          }
          values[name] = args[++i];
        }
      } else if (_flagOptions.contains(name)) {
        if (split.length > 1) {
          throw _CliException('--$name does not take a value.');
        }
        flags.add(name);
      } else {
        throw _CliException('Unknown option: --$name');
      }
    }

    return _Options(values, flags);
  }

  bool has(String name) => _values.containsKey(name) || _flags.contains(name);
  bool flag(String name) => _flags.contains(name);
  String? value(String name) => _values[name];
}

class _CliException implements Exception {
  _CliException(this.message);
  final String message;
}
