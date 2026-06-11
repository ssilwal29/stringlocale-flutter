/// Web implementation: no process environment available. Always returns null,
/// so callers must pass an explicit apiKey on web.
String? readEnv(String key) => null;
