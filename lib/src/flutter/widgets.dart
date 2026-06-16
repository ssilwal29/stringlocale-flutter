/// Flutter integration: a scope that holds the current locale + bundle, and a
/// `Tr` widget that renders a StringLocale, rebuilding on locale change.
library;

import 'package:flutter/widgets.dart';

import '../runtime/string.dart' as sl;
import '../runtime/bundle.dart';

/// Provides the active locale + bundle to the tree. Wrap your app in it.
class StringLocaleScope extends StatefulWidget {
  const StringLocaleScope({
    super.key,
    required this.locale,
    required this.bundle,
    required this.child,
  });

  final String locale;
  final Bundle bundle;
  final Widget child;

  static StringLocaleController of(BuildContext context) {
    final s = context.findAncestorStateOfType<StringLocaleController>();
    assert(s != null, 'No StringLocaleScope in context');
    return s!;
  }

  static _Inherited _inherited(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<_Inherited>();
    assert(w != null, 'No StringLocaleScope in context');
    return w!;
  }

  @override
  State<StringLocaleScope> createState() => StringLocaleController();
}

class StringLocaleController extends State<StringLocaleScope> {
  late String _locale = widget.locale;

  String get locale => _locale;
  Bundle get bundle => widget.bundle;

  @override
  void didUpdateWidget(StringLocaleScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale != widget.locale) {
      _locale = widget.locale;
    }
    if (!widget.bundle.locales.contains(_locale)) {
      widget.bundle.ensureLocale(_locale);
    }
  }

  void setLocale(String locale) {
    setState(() {
      _locale = locale;
      if (!widget.bundle.locales.contains(locale)) {
        widget.bundle.ensureLocale(locale);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      _Inherited(locale: _locale, bundle: widget.bundle, child: widget.child);
}

class _Inherited extends InheritedWidget {
  const _Inherited({
    required this.locale,
    required this.bundle,
    required super.child,
  });

  final String locale;
  final Bundle bundle;

  @override
  bool updateShouldNotify(_Inherited old) =>
      locale != old.locale || !identical(bundle, old.bundle);
}

/// Renders a [sl.StringLocale] in the scope's current locale. Resolution is
/// synchronous (offline lookup), so unlike the old render-time-LLM widget this
/// needs no FutureBuilder.
class Tr extends StatelessWidget {
  const Tr(
    this.string, {
    super.key,
    this.args = const {},
    this.builder,
  });

  final sl.StringLocale string;
  final Map<String, Object?> args;
  final Widget Function(String value)? builder;

  @override
  Widget build(BuildContext context) {
    final scope = StringLocaleScope._inherited(context);
    final value = scope.bundle.has(string.id)
        ? scope.bundle.resolve(scope.locale, string.id, args)
        : string.resolve(locale: scope.locale, args: args);
    if (builder != null) return builder!(value);
    return Text(value);
  }
}

class AsyncTr extends StatefulWidget {
  const AsyncTr(
    this.string, {
    super.key,
    this.args = const {},
    this.builder,
  });

  final sl.StringLocale string;
  final Map<String, Object?> args;
  final Widget Function(String value)? builder;

  @override
  State<AsyncTr> createState() => _AsyncTrState();
}

class _AsyncTrState extends State<AsyncTr> {
  late Future<String> _future;
  String? _lastLocale;
  Bundle? _lastBundle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = StringLocaleScope._inherited(context);
    if (_lastLocale != scope.locale || !identical(_lastBundle, scope.bundle)) {
      _future = _resolve();
      _lastLocale = scope.locale;
      _lastBundle = scope.bundle;
    }
  }

  @override
  void didUpdateWidget(covariant AsyncTr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.string != widget.string || oldWidget.args != widget.args) {
      _future = _resolve();
    }
  }

  Future<String> _resolve() {
    final scope = StringLocaleScope._inherited(context);
    return scope.bundle.has(widget.string.id)
        ? scope.bundle.resolveAsync(scope.locale, widget.string.id, widget.args)
        : Future.value(
            widget.string.resolve(locale: scope.locale, args: widget.args));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        final fallback = widget.string.resolve(
          locale: StringLocaleScope._inherited(context).locale,
          args: widget.args,
        );
        final value = snapshot.data ?? fallback;
        if (widget.builder != null) return widget.builder!(value);
        return Text(value);
      },
    );
  }
}

/// Imperative resolve from a context (for snackbars/dialogs).
String tr(BuildContext context, sl.StringLocale string,
    {Map<String, Object?> args = const {}}) {
  final scope = StringLocaleScope._inherited(context);
  return scope.bundle.has(string.id)
      ? scope.bundle.resolve(scope.locale, string.id, args)
      : string.resolve(locale: scope.locale, args: args);
}

Future<String> trAsync(BuildContext context, sl.StringLocale string,
    {Map<String, Object?> args = const {}}) {
  final scope = StringLocaleScope._inherited(context);
  return scope.bundle.has(string.id)
      ? scope.bundle.resolveAsync(scope.locale, string.id, args)
      : Future.value(string.resolve(locale: scope.locale, args: args));
}
