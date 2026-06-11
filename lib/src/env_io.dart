import 'dart:io';

/// Native (VM / Flutter mobile+desktop) implementation: read from environment.
String? readEnv(String key) => Platform.environment[key];
