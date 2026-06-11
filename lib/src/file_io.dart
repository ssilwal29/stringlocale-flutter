import 'dart:io';

/// Native: read a JSON file's contents, or null if it doesn't exist.
Future<String?> readFileIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return file.readAsString();
  }
  return null;
}
