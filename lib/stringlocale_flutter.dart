/// stringlocale for Flutter — adds widget integration on top of the pure-Dart
/// core.
///
/// Re-exports everything from `package:stringlocale/stringlocale.dart` plus
/// the Flutter widgets [StringLocaleScope], [Tr], and [trAsync].
library;

export 'stringlocale.dart';
export 'src/flutter_widgets.dart'
    show StringLocaleScope, StringLocaleScopeState, Tr, trAsync;
