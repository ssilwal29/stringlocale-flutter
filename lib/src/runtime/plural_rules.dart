/// CLDR cardinal plural rules used by both the compiler and runtime.
///
/// The rule table is generated from CLDR data and committed as plain Dart.
library;

import 'plural_rules_generated.dart';

const List<String> _categoryOrder = [
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
];

final RegExp _orPattern = RegExp(r'\s+or\s+');
final RegExp _andPattern = RegExp(r'\s+and\s+');
final RegExp _relationPattern = RegExp(
  r'^(n|i|v|w|f|t|c|e)(?:\s*(?:%|mod)\s*(\d+))?\s*'
  r'(not within|not in|is not|within|in|!=|=|is)\s*(.+)$',
);

String _normalizeLocale(String localeCode) =>
    localeCode.replaceAll('_', '-').toLowerCase();

Map<String, String>? _rulesForLocale(String localeCode) {
  final normalized = _normalizeLocale(localeCode);
  return cldrCardinalPluralRules[normalized] ??
      cldrCardinalPluralRules[normalized.split('-')[0]] ??
      cldrCardinalPluralRules['und'];
}

List<String> pluralCategories(String localeCode) {
  final rules = _rulesForLocale(localeCode);
  if (rules == null) return const ['other'];
  final categories = [
    for (final category in _categoryOrder)
      if (rules.containsKey(category)) category,
  ];
  return categories.isEmpty ? const ['other'] : categories;
}

String pluralCategory(String localeCode, Object? value) {
  final rules = _rulesForLocale(localeCode);
  if (rules == null) return 'other';

  final operands = _PluralOperands.parse(value);
  if (!operands.valid) return 'other';

  for (final category in _categoryOrder) {
    if (category == 'other') continue;
    final rule = rules[category];
    if (rule != null && rule.isNotEmpty && _matchesRule(rule, operands)) {
      return category;
    }
  }
  return 'other';
}

bool _matchesRule(String rule, _PluralOperands operands) {
  for (final orPart in rule.split(_orPattern)) {
    final andParts = orPart.split(_andPattern);
    if (andParts.every((part) => _matchesRelation(part.trim(), operands))) {
      return true;
    }
  }
  return false;
}

bool _matchesRelation(String relation, _PluralOperands operands) {
  final match = _relationPattern.firstMatch(relation);
  if (match == null) return false;

  final operandName = match.group(1)!;
  final mod = int.tryParse(match.group(2) ?? '');
  final operator = match.group(3)!;
  final ranges = match.group(4)!;

  var operand = operands.value(operandName);
  if (mod != null) operand = operand % mod;

  final contains = _rangeListContains(ranges, operand);
  switch (operator) {
    case '=':
    case 'is':
    case 'in':
    case 'within':
      return contains;
    case '!=':
    case 'is not':
    case 'not in':
    case 'not within':
      return !contains;
    default:
      return false;
  }
}

bool _rangeListContains(String ranges, num operand) {
  for (final part in ranges.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final rangeParts = trimmed.split('..');
    if (rangeParts.length == 2) {
      final start = num.tryParse(rangeParts[0].trim());
      final end = num.tryParse(rangeParts[1].trim());
      if (start != null && end != null && operand >= start && operand <= end) {
        return true;
      }
    } else {
      final value = num.tryParse(trimmed);
      if (value != null && operand == value) return true;
    }
  }
  return false;
}

class _PluralOperands {
  const _PluralOperands({
    required this.valid,
    required this.n,
    required this.i,
    required this.v,
    required this.w,
    required this.f,
    required this.t,
    required this.c,
    required this.e,
  });

  final bool valid;
  final num n;
  final int i;
  final int v;
  final int w;
  final int f;
  final int t;
  final int c;
  final int e;

  factory _PluralOperands.parse(Object? value) {
    if (value == null) return _PluralOperands.invalid();

    var text = value.toString().trim();
    if (text.isEmpty) return _PluralOperands.invalid();
    if (text.startsWith('+')) text = text.substring(1);
    if (text.startsWith('-')) text = text.substring(1);
    text = text.replaceAll(',', '');

    final parsed = num.tryParse(text);
    if (parsed == null || parsed.isNaN) return _PluralOperands.invalid();
    final absolute = parsed.abs();

    if (text.contains('e') || text.contains('E')) {
      return _PluralOperands.fromParts(
        n: absolute,
        integerDigits: absolute.truncate().toString(),
        fractionDigits: '',
      );
    }

    final pieces = text.split('.');
    final integerDigits = pieces.first.isEmpty ? '0' : pieces.first;
    final fractionDigits = pieces.length > 1 ? pieces.sublist(1).join('') : '';
    return _PluralOperands.fromParts(
      n: absolute,
      integerDigits: integerDigits,
      fractionDigits: fractionDigits,
    );
  }

  factory _PluralOperands.fromParts({
    required num n,
    required String integerDigits,
    required String fractionDigits,
  }) {
    final fractionWithoutTrailingZeros =
        fractionDigits.replaceFirst(RegExp(r'0+$'), '');
    return _PluralOperands(
      valid: true,
      n: n,
      i: int.tryParse(integerDigits) ?? n.truncate(),
      v: fractionDigits.length,
      w: fractionWithoutTrailingZeros.length,
      f: fractionDigits.isEmpty ? 0 : int.tryParse(fractionDigits) ?? 0,
      t: fractionWithoutTrailingZeros.isEmpty
          ? 0
          : int.tryParse(fractionWithoutTrailingZeros) ?? 0,
      c: 0,
      e: 0,
    );
  }

  factory _PluralOperands.invalid() => const _PluralOperands(
        valid: false,
        n: double.nan,
        i: 0,
        v: 0,
        w: 0,
        f: 0,
        t: 0,
        c: 0,
        e: 0,
      );

  num value(String operand) {
    switch (operand) {
      case 'n':
        return n;
      case 'i':
        return i;
      case 'v':
        return v;
      case 'w':
        return w;
      case 'f':
        return f;
      case 't':
        return t;
      case 'c':
        return c;
      case 'e':
        return e;
      default:
        return double.nan;
    }
  }
}

const Map<String, String> _hint = {
  'zero': 'zero items',
  'one': 'exactly one (singular)',
  'two': 'exactly two (dual)',
  'few': 'a few items',
  'many': 'many items',
  'other': 'the general/plural form',
};

String categoryHint(String category) => _hint[category] ?? category;
