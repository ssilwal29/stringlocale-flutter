library;

import 'dart:io';

String? ioFileReader(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}
