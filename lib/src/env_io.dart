import 'dart:io';

/// Native (VM / Flutter mobile+desktop) implementation: read from the process
/// environment, then from Flutter/Dart `--dart-define` values.
String? readEnv(String key) {
  final value = Platform.environment[key];
  if (value != null && value.isNotEmpty) return value;
  return switch (key) {
    'OPENROUTER_API_KEY' => const String.fromEnvironment('OPENROUTER_API_KEY'),
    _ => null,
  };
}
