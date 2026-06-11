import 'package:flutter/widgets.dart';

import 'text.dart' as sl;
import 'renderer.dart';

/// Inherited scope that provides the current locale and a [Renderer] to the
/// widget tree. Wrap your app (or a subtree) in this.
///
/// ```dart
/// StringLocaleScope(
///   localeCode: 'ne-NP',
///   languageName: 'Nepali',
///   renderer: renderer,
///   child: MyApp(),
/// )
/// ```
class StringLocaleScope extends StatefulWidget {
  /// Provide locale information and a [Renderer] to a widget subtree.
  const StringLocaleScope({
    super.key,
    required this.localeCode,
    required this.languageName,
    required this.renderer,
    required this.child,
  });

  /// Active locale code, such as `en` or `ne-NP`.
  final String localeCode;

  /// Human-readable language name for runtime LLM translation prompts.
  final String languageName;

  /// Renderer used to resolve [Message] definitions.
  final Renderer renderer;

  /// Subtree that can access this localization scope.
  final Widget child;

  /// Return the mutable state for the nearest [StringLocaleScope].
  static StringLocaleScopeState of(BuildContext context) {
    final state = context.findAncestorStateOfType<StringLocaleScopeState>();
    assert(state != null, 'No StringLocaleScope found in context');
    return state!;
  }

  static _InheritedStringLocale _inherited(BuildContext context) {
    final w =
        context.dependOnInheritedWidgetOfExactType<_InheritedStringLocale>();
    assert(w != null, 'No StringLocaleScope found in context');
    return w!;
  }

  @override
  State<StringLocaleScope> createState() => StringLocaleScopeState();
}

/// Mutable state for [StringLocaleScope], including imperative locale changes.
class StringLocaleScopeState extends State<StringLocaleScope> {
  /// Create state for a [StringLocaleScope].
  StringLocaleScopeState();

  late String _localeCode = widget.localeCode;
  late String _languageName = widget.languageName;

  /// Current active locale code.
  String get localeCode => _localeCode;

  /// Current active human-readable language name.
  String get languageName => _languageName;

  /// Renderer supplied by the surrounding [StringLocaleScope].
  Renderer get renderer => widget.renderer;

  /// Switch the active locale. Rebuilds dependents.
  void setLocale(String localeCode, String languageName) {
    setState(() {
      _localeCode = localeCode;
      _languageName = languageName;
    });
  }

  @override
  void didUpdateWidget(covariant StringLocaleScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localeCode != oldWidget.localeCode ||
        widget.languageName != oldWidget.languageName) {
      _localeCode = widget.localeCode;
      _languageName = widget.languageName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedStringLocale(
      localeCode: _localeCode,
      languageName: _languageName,
      renderer: widget.renderer,
      child: widget.child,
    );
  }
}

class _InheritedStringLocale extends InheritedWidget {
  const _InheritedStringLocale({
    required this.localeCode,
    required this.languageName,
    required this.renderer,
    required super.child,
  });

  final String localeCode;
  final String languageName;
  final Renderer renderer;

  @override
  bool updateShouldNotify(_InheritedStringLocale old) =>
      localeCode != old.localeCode || languageName != old.languageName;
}

/// A widget that renders a [Message] definition in the current locale, handling
/// the async translation transparently. Shows [fallback] (or the English
/// source) until the translation resolves.
///
/// ```dart
/// Tr(welcome)
/// Tr(pageCount, args: {'count': 5})
/// Tr(websiteStatus, args: {'status': 'approved'},
///    builder: (s) => Text(s, style: myStyle))
/// ```
class Tr extends StatefulWidget {
  /// Render [text] using the nearest [StringLocaleScope].
  const Tr(
    this.text, {
    super.key,
    this.args = const {},
    this.fallback,
    this.builder,
  });

  /// Message definition to render.
  final sl.Message text;

  /// Runtime parameter values keyed by placeholder name.
  final Map<String, Object?> args;

  /// Shown while the translation resolves. Defaults to the English source.
  final String? fallback;

  /// Optional builder to wrap the resolved string in a custom widget.
  /// If omitted, a plain [Text] widget is used.
  final Widget Function(String value)? builder;

  @override
  State<Tr> createState() => _TrState();
}

class _TrState extends State<Tr> {
  String? _value;
  String _renderKey = '';

  String get _fallback {
    if (widget.fallback != null) return widget.fallback!;
    return widget.text.isPlural
        ? widget.text.source.split(sl.pluralSep)[0]
        : widget.text.source;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRender();
  }

  @override
  void didUpdateWidget(Tr old) {
    super.didUpdateWidget(old);
    _maybeRender();
  }

  void _maybeRender() {
    final scope = StringLocaleScope._inherited(context);
    final key = '${widget.text.key}::${scope.localeCode}::${widget.args}';
    if (key == _renderKey) return;
    _renderKey = key;

    scope.renderer
        .render(
      widget.text,
      scope.localeCode,
      languageName: scope.languageName,
      args: widget.args,
    )
        .then((result) {
      if (mounted && _renderKey == key) {
        setState(() => _value = result);
      }
    }).catchError((_) {
      if (mounted) setState(() => _value = _fallback);
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _value ?? _fallback;
    if (widget.builder != null) return widget.builder!(value);
    return Text(value);
  }
}

/// Convenience: imperatively render a [Message] from a [BuildContext].
/// Returns a [Future] — for use in event handlers, not build methods.
Future<String> trAsync(
  BuildContext context,
  sl.Message text, {
  Map<String, Object?> args = const {},
}) {
  final scope = StringLocaleScope._inherited(context);
  return scope.renderer.render(
    text,
    scope.localeCode,
    languageName: scope.languageName,
    args: args,
  );
}
