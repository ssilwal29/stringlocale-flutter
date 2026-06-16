/// Default OpenRouter-backed adapter for userAdapted params.
///
/// On non-IO platforms, this returns null so the runtime falls back to
/// passthrough.

library;

String Function(String value, String locale, String? context)?
    defaultAdapter() => null;

Future<String> Function(String value, String locale, String? context)?
    defaultAsyncAdapter() => null;
