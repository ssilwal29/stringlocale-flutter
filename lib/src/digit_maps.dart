const String asciiDigits = '0123456789';
const String devanagariDigits = '०१२३४५६७८९';
const String arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
const String easternArabicIndicDigits = '۰۱۲۳۴۵۶۷۸۹';
const String bengaliDigits = '০১২৩৪৫৬৭৮৯';
const String gurmukhiDigits = '੦੧੨੩੪੫੬੭੮੯';
const String gujaratiDigits = '૦૧૨૩૪૫૬૭૮૯';
const String odiaDigits = '୦୧୨୩୪୫୬୭୮୯';
const String tamilDigits = '௦௧௨௩௪௫௬௭௮௯';
const String teluguDigits = '౦౧౨౩౪౫౬౭౮౯';
const String kannadaDigits = '೦೧೨೩೪೫೬೭೮೯';
const String malayalamDigits = '൦൧൨൩൪൫൬൭൮൯';
const String thaiDigits = '๐๑๒๓๔๕๖๗๘๙';
const String laoDigits = '໐໑໒໓໔໕໖໗໘໙';
const String tibetanDigits = '༠༡༢༣༤༥༦༧༨༩';
const String myanmarDigits = '၀၁၂၃၄၅၆၇၈၉';
const String khmerDigits = '០១២៣៤៥៦៧៨៩';

/// Per-locale or per-language digit maps used by [formatNumber].
///
/// Exact locale/script keys should be lowercase and use hyphens. When no
/// exact locale key exists, callers fall back to the base language code.
const Map<String, String> digitMaps = {
  // ASCII digits remain the default for many modern app UIs.
  'en': asciiDigits,
  'de': asciiDigits,
  'es': asciiDigits,
  'fr': asciiDigits,
  'it': asciiDigits,
  'ja': asciiDigits,
  'ko': asciiDigits,
  'nl': asciiDigits,
  'pt': asciiDigits,
  'ru': asciiDigits,
  'tr': asciiDigits,
  'vi': asciiDigits,
  'zh': asciiDigits,

  // Devanagari
  'hi': devanagariDigits,
  'mr': devanagariDigits,
  'ne': devanagariDigits,

  // Arabic-Indic
  'ar': arabicIndicDigits,

  // Eastern Arabic-Indic
  'fa': easternArabicIndicDigits,
  'ps': easternArabicIndicDigits,
  'ur': easternArabicIndicDigits,

  // Bengali-Assamese
  'as': bengaliDigits,
  'bn': bengaliDigits,

  // Gurmukhi Punjabi only when explicitly requested by locale/script.
  'pa-guru': gurmukhiDigits,
  'pa-in': gurmukhiDigits,

  // Other Indic scripts
  'gu': gujaratiDigits,
  'kn': kannadaDigits,
  'ml': malayalamDigits,
  'or': odiaDigits,
  'ta': tamilDigits,
  'te': teluguDigits,

  // Southeast Asian scripts
  'km': khmerDigits,
  'lo': laoDigits,
  'my': myanmarDigits,
  'th': thaiDigits,

  // Tibetan script
  'bo': tibetanDigits,
  'dz': tibetanDigits,
};
