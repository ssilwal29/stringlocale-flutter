/// Core text definition types for stringlocale.
library;

/// Sentinel that encodes both plural forms into a single source string.
/// Never appears in real UI text.
const String pluralSep = '|||';

/// What a template parameter *is* — determines how it's resolved at render time.
enum ParamKind {
  /// Brand names, URLs, IDs — passed through unchanged.
  literal('literal'),

  /// Enum-like UI labels (status, category) — translated at runtime via LLM.
  translatable('translatable'),

  /// Numeric values — digit-converted per locale.
  number('number'),

  /// Numeric value that also drives singular/plural form selection.
  numberPlural('number_plural'),

  /// Date values — formatted per locale (Gregorian via intl).
  date('date'),

  /// Monetary amounts — formatted per locale with currency symbol.
  currency('currency'),

  /// Relative time ("3 days ago") — formatted per locale.
  relative('relative'),

  /// User-authored free text — passed through unchanged.
  user('user'),

  /// Free text whose dates/numbers/currency are LLM-converted per locale,
  /// prose left untranslated; content-hash cached at runtime.
  userAdapted('user_adapted');

  const ParamKind(this.wire);

  /// The string value used in JSON / wire format.
  final String wire;

  /// Parse a JSON / wire value into a [ParamKind].
  static ParamKind fromWire(String wire) =>
      ParamKind.values.firstWhere((k) => k.wire == wire);
}

/// A single template parameter declaration.
class Param {
  /// Create a parameter named [name] with formatting and translation metadata.
  const Param(
    this.name, {
    this.kind = ParamKind.literal,
    this.context,
    this.fmt,
    this.currency,
  });

  /// Placeholder name without braces, such as `count` for `{count}`.
  final String name;

  /// How this parameter should be handled during rendering.
  final ParamKind kind;

  /// Hint passed to the LLM when kind is [ParamKind.translatable] or
  /// [ParamKind.userAdapted].
  final String? context;

  /// For [ParamKind.date]: one of 'short' | 'medium' | 'long' | 'full',
  /// or a custom intl skeleton.
  final String? fmt;

  /// For [ParamKind.currency]: ISO 4217 code, e.g. 'NPR', 'USD'.
  final String? currency;

  @override
  String toString() => 'Param($name, ${kind.wire})';
}

/// Extract all `{name}` placeholder names from a template string.
Set<String> extractPlaceholders(String source) {
  final re = RegExp(r'\{(\w+)\}');
  return re.allMatches(source).map((m) => m.group(1)!).toSet();
}

/// A localizable message (text) definition.
class Message {
  /// Create a message definition and validate declared placeholders.
  Message({
    required this.key,
    required this.source,
    this.params = const [],
  }) {
    _validate();
  }

  /// Stable lookup key used in generated locale JSON.
  final String key;

  /// English source template, or encoded singular/plural source for plurals.
  final String source;

  /// Declared parameters that may appear in [source].
  final List<Param> params;

  /// Whether this message has any runtime parameters.
  bool get isDynamic => params.isNotEmpty;

  /// Whether this message contains encoded plural forms.
  bool get isPlural => source.contains(pluralSep);

  void _validate() {
    final Set<String> placeholders;
    if (isPlural) {
      final parts = source.split(pluralSep);
      placeholders = {
        ...extractPlaceholders(parts[0]),
        ...extractPlaceholders(parts.length > 1 ? parts[1] : ''),
      };
    } else {
      placeholders = extractPlaceholders(source);
    }

    final paramNames = params.map((p) => p.name).toSet();
    final missing = placeholders.difference(paramNames);
    final extra = paramNames.difference(placeholders);

    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Text "$key": placeholders {${missing.join(', ')}} '
        'are in source but not declared in params',
      );
    }
    if (extra.isNotEmpty) {
      throw ArgumentError(
        'Text "$key": params [${extra.join(', ')}] '
        'are declared but not in source template',
      );
    }
  }

  /// Return the parameter declaration named [name], or `null` if absent.
  Param? param(String name) {
    for (final p in params) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  String toString() => 'Text($key)';
}

/// Define a static UI string with no runtime parameters.
///
/// Named [staticText] because `static` is a reserved word in Dart.
/// The short alias [t] is also available.
Message staticText(String key, String source) =>
    Message(key: key, source: source, params: const []);

/// Short alias for [staticText].
Message t(String key, String source) => staticText(key, source);

/// Define a dynamic UI string with typed parameters.
///
/// ```dart
/// final status = dynamicText('website_status', 'Website status: {status}', {
///   'status': Param('status', kind: ParamKind.translatable, context: 'status'),
/// });
/// ```
///
/// Params may be given as a [ParamKind] (shorthand) or a full [Param].
Message dynamicText(String key, String source, Map<String, Object> paramDefs) {
  final params = <Param>[];
  paramDefs.forEach((name, def) {
    if (def is Param) {
      params.add(def);
    } else if (def is ParamKind) {
      params.add(Param(name, kind: def));
    } else {
      throw ArgumentError('Param "$name" must be a ParamKind or Param');
    }
  });
  return Message(key: key, source: source, params: params);
}

/// Backward-compatible alias for [dynamicText].
///
/// Prefer [dynamicText] in new code because it describes the message shape
/// without colliding with Dart's `dynamic` keyword.
Message message(String key, String source, Map<String, Object> paramDefs) =>
    dynamicText(key, source, paramDefs);

/// Backward-compatible alias for [dynamicText].
///
/// `dynamic` is a Dart keyword, so older examples used `dynamic_()`.
Message dynamic_(String key, String source, Map<String, Object> paramDefs) =>
    dynamicText(key, source, paramDefs);

/// Define a plural-aware UI string. The LLM generates both forms plus the
/// language-specific plural rule at compile time. The renderer picks the
/// correct form at runtime — no LLM call at render time.
///
/// ```dart
/// final pages = pluralText(
///   'page_count',
///   'You have {count} localized page',
///   'You have {count} localized pages',
/// );
/// ```
Message pluralText(
  String key,
  String singular,
  String pluralForm, {
  String countParam = 'count',
  Map<String, Object> params = const {},
}) {
  final allParams = <Param>[
    Param(countParam, kind: ParamKind.numberPlural),
  ];
  params.forEach((name, def) {
    if (def is Param) {
      allParams.add(def);
    } else if (def is ParamKind) {
      allParams.add(Param(name, kind: def));
    } else {
      throw ArgumentError('Param "$name" must be a ParamKind or Param');
    }
  });

  return Message(
    key: key,
    source: '$singular$pluralSep$pluralForm',
    params: allParams,
  );
}

/// Backward-compatible alias for [pluralText].
///
/// Prefer [pluralText] in new code because it reads more clearly beside
/// [staticText] and [message].
Message plural(
  String key,
  String singular,
  String pluralForm, {
  String countParam = 'count',
  Map<String, Object> params = const {},
}) =>
    pluralText(
      key,
      singular,
      pluralForm,
      countParam: countParam,
      params: params,
    );
