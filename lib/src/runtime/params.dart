/// Param kinds — the declaration vocabulary, mirroring the Python package.
///
///   literal       pass-through                                  (offline)
///   number        digit-converted per locale                    (offline)
///   date          locale date formatting                        (offline)
///   currency      locale currency formatting                    (offline)
///   relative      "3 days ago" formatting                       (offline)
///   translatable  ENUM AXIS — values pre-translated, substituted (offline)
///   plural        TEMPLATE AXIS — CLDR forms pre-drafted          (offline)
///   user          pass-through free text                         (offline)
///   userAdapted   LLM reformats prose at runtime                 (online hatch)
library;

enum ParamKind {
  literal('literal'),
  number('number'),
  date('date'),
  currency('currency'),
  relative('relative'),
  translatable('translatable'),
  plural('plural'),
  user('user'),
  userAdapted('user_adapted');

  const ParamKind(this.wire);
  final String wire;

  static ParamKind fromWire(String wire) =>
      ParamKind.values.firstWhere((k) => k.wire == wire);
}

/// Describes how a single placeholder in a [StringLocale] string behaves —
/// how it is formatted, whether it drives axis selection, and whether it
/// is resolved offline or requires an LLM adapter at runtime.
///
/// Use the static factories (`Param.literal()`, `Param.date()`, etc.) rather
/// than constructing this class directly.
class Param {
  const Param(
    this.kind, {
    this.values,
    this.context,
    this.fmt,
    this.currencyCode,
    this.inline = false,
  });

  final ParamKind kind;

  /// translatable: the closed value set (becomes an enum axis).
  final List<String>? values;

  /// translatable / userAdapted: hint for the LLM.
  final String? context;

  /// date: 'short' | 'medium' | 'long' | 'full'.
  final String? fmt;

  /// currency: ISO 4217 code.
  final String? currencyCode;

  /// translatable: fold into the template cross-product (grammatical agreement).
  final bool inline;

  // ── factories (the public vocabulary) ───────────────────────────────────────

  /// Pass-through string — value is inserted as-is with no formatting.
  static Param literal() => const Param(ParamKind.literal);

  /// Locale-aware number with digit conversion (e.g. Arabic-Indic numerals).
  static Param number() => const Param(ParamKind.number);

  /// Locale date formatting. [fmt] is one of `'short'`, `'medium'` (default),
  /// `'long'`, or `'full'`. The value passed at resolve time must be an ISO
  /// 8601 date string (`'2026-07-15'`) or a [DateTime].
  static Param date([String fmt = 'medium']) => Param(ParamKind.date, fmt: fmt);

  /// Locale currency formatting. [code] is an ISO 4217 currency code
  /// (e.g. `'USD'`, `'NPR'`).
  static Param currency(String code) =>
      Param(ParamKind.currency, currencyCode: code);

  /// Relative-time formatting resolved at runtime (e.g. "3 days ago",
  /// "in 2 hours"). Value must be a [Duration] or an ISO 8601 date string.
  static Param relative() => const Param(ParamKind.relative);

  /// Closed enum axis — [values] are the allowed strings. The compiler
  /// pre-translates each value and substitutes the result at runtime (offline).
  ///
  /// Set [inline] to `true` when the value must grammatically agree with the
  /// surrounding sentence (e.g. gendered adjectives); the compiler then expands
  /// it into the template cross-product rather than a separate lookup table.
  ///
  /// [context] is a hint passed to the LLM during compilation.
  static Param translatable(
    List<String> values, {
    String? context,
    bool inline = false,
  }) =>
      Param(
        ParamKind.translatable,
        values: values,
        context: context,
        inline: inline,
      );

  /// CLDR plural axis. The value passed at resolve time must be a number;
  /// the runtime selects the correct plural form (one / other / few / many /
  /// zero) for the active locale.
  static Param plural() => const Param(ParamKind.plural);

  /// Free-text pass-through — inserted verbatim, never sent to an LLM.
  static Param user() => const Param(ParamKind.user);

  /// Free prose reformatted for the active locale by an async LLM adapter at
  /// runtime. Falls back to the original value when no adapter is configured.
  ///
  /// [context] is an optional hint for the adapter describing how the param
  /// is used (e.g. `'Short note shown to shoppers on product cards'`).
  static Param userAdapted({String? context}) =>
      Param(ParamKind.userAdapted, context: context);

  @override
  String toString() => 'Param.${kind.wire}';
}
