import 'package:intl/intl.dart';

import 'digit_maps.dart';

/// Convert ASCII digits in [value] to the locale-native digit set.
///
/// If [localeCode] has no known digit map, returns [value] unchanged as text.
String formatNumber(Object value, String localeCode) {
  final digitStr = _digitMapForLocale(localeCode);
  final text = value.toString();
  if (digitStr == null) return text;
  // Each native digit may be a single rune; index by rune for safety.
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

String? _digitMapForLocale(String localeCode) {
  final normalized = localeCode.replaceAll('_', '-').toLowerCase();
  return digitMaps[normalized] ?? digitMaps[normalized.split('-').first];
}

DateTime _toDate(Object value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  throw ArgumentError('Cannot interpret $value as a date');
}

/// Format a date per locale. [fmt] is one of short/medium/long/full.
///
/// Gregorian only — for Bikram Sambat or other calendars, format yourself
/// and pass as a literal param.
String formatDateValue(Object value, String localeCode, [String? fmt]) {
  final d = _toDate(value);
  final intlLocale = localeCode.replaceAll('-', '_');
  final style = fmt ?? 'medium';
  try {
    final DateFormat formatter;
    switch (style) {
      case 'short':
        formatter = DateFormat.yMd(intlLocale);
        break;
      case 'long':
        formatter = DateFormat.yMMMMd(intlLocale);
        break;
      case 'full':
        formatter = DateFormat.yMMMMEEEEd(intlLocale);
        break;
      case 'medium':
      default:
        formatter = DateFormat.yMMMd(intlLocale);
        break;
    }
    return formatter.format(d);
  } catch (_) {
    return d.toIso8601String().split('T')[0];
  }
}

/// Format a monetary amount per locale. [currency] is an ISO 4217 code.
String formatCurrencyValue(Object value, String localeCode,
    [String? currency]) {
  final amount =
      value is num ? value.toDouble() : double.parse(value.toString());
  final cur = currency ?? 'USD';
  final intlLocale = localeCode.replaceAll('-', '_');
  try {
    final formatter = NumberFormat.simpleCurrency(
      locale: intlLocale,
      name: cur,
    );
    return formatter.format(amount);
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

const List<MapEntry<String, int>> _relativeUnits = [
  MapEntry('year', 60 * 60 * 24 * 365),
  MapEntry('month', 60 * 60 * 24 * 30),
  MapEntry('week', 60 * 60 * 24 * 7),
  MapEntry('day', 60 * 60 * 24),
  MapEntry('hour', 60 * 60),
  MapEntry('minute', 60),
  MapEntry('second', 1),
];

/// Format a relative time. [value] may be a [Duration], [DateTime], or seconds
/// (num; negative = past).
///
/// Note: intl has no RelativeTimeFormat equivalent, so this produces English
/// phrasing. For full locale-aware relative time, override the string or pass
/// a pre-formatted literal.
String formatRelativeValue(Object value, String localeCode) {
  int seconds;
  if (value is Duration) {
    seconds = value.inSeconds;
  } else if (value is DateTime) {
    seconds = value.difference(DateTime.now()).inSeconds;
  } else if (value is num) {
    seconds = value.toInt();
  } else {
    throw ArgumentError('Cannot interpret $value as relative time');
  }

  final past = seconds < 0;
  final abs = seconds.abs();
  for (final entry in _relativeUnits) {
    if (abs >= entry.value) {
      final n = (abs / entry.value).round();
      final s = n != 1 ? 's' : '';
      return past ? '$n ${entry.key}$s ago' : 'in $n ${entry.key}$s';
    }
  }
  return 'just now';
}
