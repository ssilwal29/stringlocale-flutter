/// Web implementation: no process environment is available, so read values
/// passed with Flutter/Dart `--dart-define`.
String? readEnv(String key) {
  return switch (key) {
    'OPENROUTER_API_KEY' => const String.fromEnvironment('OPENROUTER_API_KEY'),
    _ => null,
  };
}
