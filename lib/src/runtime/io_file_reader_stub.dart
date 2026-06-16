library;

String? ioFileReader(String path) {
  throw UnsupportedError(
    'ioFileReader is only available on platforms with dart:io. '
    'Pass a custom FileReader to Bundle.fromDir on web.',
  );
}
