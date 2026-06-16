/// stringlocale — declare strings with typed params, compile to offline locale
/// bundles, resolve by locale at runtime.
///
/// Pure-Dart core (no Flutter). For Flutter widgets, import
/// `package:stringlocale/flutter.dart`.
library;

import 'src/runtime/bundle.dart';
import 'src/runtime/io_file_reader_stub.dart'
    if (dart.library.io) 'src/runtime/io_file_reader_io.dart' as io_reader;
import 'src/runtime/string.dart';

export 'src/runtime/params.dart' show Param, ParamKind;
export 'src/runtime/string.dart'
    show
        StringLocale,
        setLocale,
        getLocale,
        useBundle,
        currentBundle,
        getRegistry,
        clearRegistry;
export 'src/runtime/bundle.dart'
    show
        Bundle,
        Adapter,
        AsyncAdapter,
        UserAdaptedMode,
        FileReader,
        MissingRequiredAxis,
        StringNotFound,
        pluralToken;
export 'src/runtime/plural_rules.dart' show pluralCategory, pluralCategories;
export 'src/runtime/formatters.dart'
    show
        convertDigits,
        formatDateValue,
        formatCurrencyValue,
        formatRelativeValue;

/// Read a file with dart:io (VM / Flutter mobile+desktop). On web, pass your
/// own FileReader (e.g. backed by rootBundle) to Bundle.fromDir.
String? ioFileReader(String path) {
  return io_reader.ioFileReader(path);
}

/// Convenience: load a compiled bundle directory using dart:io and make it the
/// active bundle. Mirrors the Python `load("dist")`.
Bundle load(
  String directory, {
  String? locale,
  AsyncAdapter? asyncAdapter,
  UserAdaptedMode userAdaptedMode = UserAdaptedMode.cached,
  Map<String, List<String>>? fallbacks,
  Adapter? adapter,
}) {
  final bundle = Bundle.fromDir(
    directory,
    ioFileReader,
    locales: locale != null ? [locale] : null,
    asyncAdapter: asyncAdapter,
    userAdaptedMode: userAdaptedMode,
    fallbacks: fallbacks,
    adapter: adapter,
  );
  useBundle(bundle, locale: locale);
  return bundle;
}
