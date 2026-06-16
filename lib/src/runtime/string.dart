/// StringLocale — the one object a developer holds. Mirrors the Python design:
/// each instance is a localizable string that auto-registers and carries
/// `.resolve()`, with library-level `load()` / `setLocale()` for the app case.
library;

import 'params.dart';
import 'bundle.dart';
import 'formatters.dart';

final RegExp _placeholderRe = RegExp(r'\{(\w+)\}');

// Global registry — populated as StringLocale instances are constructed.
final Map<String, StringLocale> _registry = {};

// ── library-level current state (the app convenience) ─────────────────────────

String _currentLocale = 'en';
Bundle? _currentBundle;

/// Attach an already-constructed Bundle as the active one and (optionally) set
/// the current locale. (Dart can't read files portably from this layer, so the
/// caller builds the Bundle via Bundle.fromDir(reader) or fromJsonString.)
void useBundle(Bundle? bundle, {String? locale}) {
  _currentBundle = bundle;
  if (locale != null) setLocale(locale);
}

/// Set the active locale for library-level `StringLocale.resolve()` calls.
///
/// If the current bundle does not yet contain data for [locale], it is loaded
/// lazily via [Bundle.ensureLocale].
void setLocale(String locale) {
  _currentLocale = locale;
  if (_currentBundle != null && !_currentBundle!.locales.contains(locale)) {
    _currentBundle!.ensureLocale(locale);
  }
}

/// The currently active locale tag (e.g. `'en-US'`, `'fr-FR'`).
String getLocale() => _currentLocale;

/// The currently active [Bundle], or `null` if none has been set.
Bundle? currentBundle() => _currentBundle;

/// All [StringLocale] instances that have been constructed and auto-registered,
/// keyed by their `id`.
Map<String, StringLocale> getRegistry() => Map.of(_registry);

/// Clear the global registry. Useful in tests to reset state between runs.
void clearRegistry() => _registry.clear();

Set<String> _placeholders(String text) =>
    _placeholderRe.allMatches(text).map((m) => m.group(1)!).toSet();

/// A localizable string with typed parameter descriptors.
///
/// Declare one instance per string, typically as a top-level or static
/// constant. Each instance auto-registers itself under its [id] so the
/// compiler can discover all strings without manual wiring.
///
/// ```dart
/// final greeting = StringLocale(
///   'Hello, {name}!',
///   id: 'app.greeting',
///   params: {'name': Param.literal()},
/// );
///
/// // Resolve synchronously using the active bundle + locale:
/// print(greeting.resolve(args: {'name': 'Mira'}));
/// ```
///
/// For strings with [Param.userAdapted] params use [Bundle.resolveAsync]
/// (or the Flutter [AsyncTr] widget) to await the LLM adapter.
class StringLocale {
  /// Creates a [StringLocale].
  ///
  /// [text] is the English (source-locale) template with `{placeholder}`
  /// markers. [id] must be unique across the app and stable across releases —
  /// it is the key used in compiled bundle files.
  ///
  /// [params] maps each placeholder name to a [Param] descriptor. Placeholders
  /// not listed in [params] are treated as [Param.literal].
  ///
  /// Set [gendered] to `true` to automatically add a `gender` axis
  /// (`['male', 'female']`) and mark it required.
  ///
  /// [axes] declares additional segmentation axes beyond gender and plural
  /// (e.g. `{'audience': ['buyer', 'seller']}`). [required] lists axis names
  /// that must be supplied at resolve time.
  ///
  /// Set [replace] to `true` to overwrite an existing registration for the
  /// same [id] (useful in tests).
  StringLocale(
    this.text, {
    required this.id,
    this.params = const {},
    this.gendered = false,
    Map<String, List<String>> axes = const {},
    List<String> required = const [],
    this.digitConversion = true,
    this.replace = false,
  })  : axes = Map.of(axes),
        required = List.of(required) {
    _init();
  }

  final String text;
  final String id;
  final Map<String, Param> params;
  final bool gendered;
  Map<String, List<String>> axes;
  List<String> required;
  final bool digitConversion;
  final bool replace;

  // derived
  late final Map<String, List<String>> freeAxes;
  String? pluralParam;
  final Map<String, List<String>> enums = {};
  final List<String> inlinedEnums = [];
  final Map<String, String> enumContext = {};
  final List<String> number = [];
  final Map<String, String> date = {};
  final Map<String, String> currency = {};
  final List<String> relative = [];
  final List<String> userAdapted = [];
  final Map<String, String> userAdaptedContext = {};

  void _init() {
    if (gendered && !axes.containsKey('gender')) {
      axes = {
        ...axes,
        'gender': ['male', 'female']
      };
      if (!required.contains('gender')) required = [...required, 'gender'];
    }
    freeAxes = Map.of(axes);
    _sortParams();
    _validate();
    _register();
  }

  void _sortParams() {
    params.forEach((name, p) {
      switch (p.kind) {
        case ParamKind.plural:
          if (pluralParam != null) {
            throw ArgumentError(
                "$id: more than one plural param ('$pluralParam' and '$name')");
          }
          pluralParam = name;
          if (!number.contains(name)) number.add(name);
          break;
        case ParamKind.translatable:
          enums[name] = List.of(p.values ?? const []);
          if (p.context != null) enumContext[name] = p.context!;
          if (p.inline) inlinedEnums.add(name);
          break;
        case ParamKind.number:
          number.add(name);
          break;
        case ParamKind.date:
          date[name] = p.fmt ?? 'medium';
          break;
        case ParamKind.currency:
          currency[name] = p.currencyCode ?? 'USD';
          break;
        case ParamKind.relative:
          relative.add(name);
          break;
        case ParamKind.userAdapted:
          userAdapted.add(name);
          if (p.context != null) userAdaptedContext[name] = p.context!;
          break;
        case ParamKind.literal:
        case ParamKind.user:
          break; // pass-through
      }
    });
  }

  Map<String, List<String>> get substitutedEnums => {
        for (final e in enums.entries)
          if (!inlinedEnums.contains(e.key)) e.key: e.value
      };

  Set<String> get placeholders => _placeholders(text);

  void _validate() {
    final ph = placeholders;
    for (final name in params.keys) {
      if (!ph.contains(name)) {
        throw ArgumentError("$id: param '$name' is not a placeholder in text");
      }
    }
  }

  void _register() {
    final existing = _registry[id];
    if (existing != null && !replace && !identical(existing, this)) {
      if (!existing._sameDeclaration(this)) {
        throw ArgumentError(
            "Duplicate id '$id' with different declaration. Pass replace: true to override.");
      }
      return;
    }
    _registry[id] = this;
  }

  bool _sameDeclaration(StringLocale other) =>
      text == other.text &&
      gendered == other.gendered &&
      digitConversion == other.digitConversion &&
      _sameStringMap(axes, other.axes) &&
      _sameStringList(required, other.required) &&
      _sameParamMap(params, other.params);

  // axis metadata for the compiler ─────────────────────────────────────────────

  List<String> get templateAxisOrder {
    final order = freeAxes.keys.toList()..sort();
    if (pluralParam != null) order.add(pluralToken);
    order.addAll(inlinedEnums);
    return order;
  }

  bool get usesRuntimeLlm => userAdapted.isNotEmpty;

  // ── resolve ──────────────────────────────────────────────────────────────────

  /// Resolve this string for [locale] (defaults to [getLocale]) with [args].
  ///
  /// Uses the active [Bundle] when available; falls back to naive
  /// in-process resolution (no translations, no axis selection) otherwise.
  /// For `userAdapted` params use [Bundle.resolveAsync] instead.
  String resolve({String? locale, Map<String, Object?> args = const {}}) {
    final loc = locale ?? _currentLocale;
    if (_currentBundle != null && _currentBundle!.has(id)) {
      return _currentBundle!.resolve(loc, id, args);
    }
    return _naive(loc, args);
  }

  String _naive(String locale, Map<String, Object?> args) {
    String conv(String s) => digitConversion ? convertDigits(s, locale) : s;
    return text.replaceAllMapped(_placeholderRe, (m) {
      final name = m.group(1)!;
      if (!args.containsKey(name)) return m.group(0)!;
      final raw = args[name];
      if (date.containsKey(name)) {
        return conv(formatDateValue(raw!, locale, date[name]));
      }
      if (currency.containsKey(name)) {
        return conv(formatCurrencyValue(raw!, locale, currency[name]));
      }
      if (relative.contains(name)) {
        return conv(formatRelativeValue(raw!, locale));
      }
      if (number.contains(name)) return conv(raw.toString());
      return raw.toString();
    });
  }

  @override
  String toString() => "StringLocale('$id')";
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameStringMap(Map<String, List<String>> a, Map<String, List<String>> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || !_sameStringList(entry.value, other)) return false;
  }
  return true;
}

bool _sameParamMap(Map<String, Param> a, Map<String, Param> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || !_sameParam(entry.value, other)) return false;
  }
  return true;
}

bool _sameParam(Param a, Param b) =>
    a.kind == b.kind &&
    a.context == b.context &&
    a.fmt == b.fmt &&
    a.currencyCode == b.currencyCode &&
    a.inline == b.inline &&
    _sameNullableStringList(a.values, b.values);

bool _sameNullableStringList(List<String>? a, List<String>? b) {
  if (a == null || b == null) return a == b;
  return _sameStringList(a, b);
}
