/// Web: no filesystem. loadLocale() is unsupported on web — pass localeData
/// to the Renderer constructor instead (e.g. from bundled assets via rootBundle).
Future<String?> readFileIfExists(String path) async {
  throw UnsupportedError(
    'Renderer.loadLocale() is not supported on web. '
    'Pass localeData to the Renderer constructor instead.',
  );
}
