/// Locale-aware value formatters, mirroring the Python runtime.
///
/// Uses `package:intl` for date/currency. Digit conversion is pure-Dart.
/// Gregorian only — for Bikram Sambat etc., pre-format and pass as a literal.
library;

import 'package:intl/intl.dart';

const Map<String, String> _digitMaps = {
  'ne': '०१२३४५६७८९',
  'hi': '०१२३४५६७८९',
  'mr': '०१२३४५६७८९',
  'ar': '٠١٢٣٤٥٦٧٨٩',
  'fa': '۰۱۲۳۴۵۶۷۸۹',
  'bn': '০১২৩৪৫৬৭৮৯',
  'th': '๐๑๒๓๔๕๖๗๘๙',
};

String convertDigits(String text, String localeCode) {
  final lang = localeCode.replaceAll('_', '-').split('-')[0].toLowerCase();
  final digitStr = _digitMaps[lang];
  if (digitStr == null) return text;
  final digitRunes = digitStr.runes.toList();
  final buf = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buf.writeCharCode(digitRunes[rune - 0x30]);
    } else {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

DateTime _toDate(Object value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  throw ArgumentError('Cannot interpret $value as a date');
}

String formatDateValue(Object value, String localeCode, [String? fmt]) {
  final d = _toDate(value);
  final intlLocale = localeCode.replaceAll('-', '_');
  final style = fmt ?? 'medium';
  try {
    final DateFormat f;
    switch (style) {
      case 'short':
        f = DateFormat.yMd(intlLocale);
        break;
      case 'long':
        f = DateFormat.yMMMMd(intlLocale);
        break;
      case 'full':
        f = DateFormat.yMMMMEEEEd(intlLocale);
        break;
      default:
        f = DateFormat.yMMMd(intlLocale);
    }
    return f.format(d);
  } catch (_) {
    return d.toIso8601String().split('T')[0];
  }
}

String formatCurrencyValue(Object value, String localeCode,
    [String? currency]) {
  final amount =
      value is num ? value.toDouble() : double.parse(value.toString());
  final cur = currency ?? 'USD';
  final intlLocale = localeCode.replaceAll('-', '_');
  try {
    return NumberFormat.simpleCurrency(locale: intlLocale, name: cur)
        .format(amount);
  } catch (_) {
    const symbols = {
      'USD': r'$',
      'EUR': '€',
      'GBP': '£',
      'NPR': 'Rs.',
      'INR': '₹',
      'JPY': '¥',
    };
    final sym = symbols[cur] ?? '$cur ';
    return '$sym${amount.toStringAsFixed(2)}';
  }
}

String formatRelativeValue(Object value, String localeCode) {
  int secs;
  if (value is Duration) {
    secs = value.inSeconds;
  } else if (value is DateTime) {
    secs = value.difference(DateTime.now()).inSeconds;
  } else if (value is num) {
    secs = value.toInt();
  } else {
    throw ArgumentError('Cannot interpret $value as relative time');
  }
  final past = secs < 0;
  final abs = secs.abs();
  final units = <List<Object>>[
    ['year', 60 * 60 * 24 * 365],
    ['month', 60 * 60 * 24 * 30],
    ['week', 60 * 60 * 24 * 7],
    ['day', 60 * 60 * 24],
    ['hour', 60 * 60],
    ['minute', 60],
    ['second', 1],
  ];
  for (final u in units) {
    final unit = u[0] as String;
    final size = u[1] as int;
    if (abs >= size) {
      final nn = (abs / size).round();
      final s = nn != 1 ? 's' : '';
      return past ? '$nn $unit$s ago' : 'in $nn $unit$s';
    }
  }
  return 'just now';
}
