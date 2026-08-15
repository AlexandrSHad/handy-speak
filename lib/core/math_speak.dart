import 'app_language.dart';

/// Spoken-word map for math glyphs (POC `MATH_SPEAK`). Exactly the seven
/// glyphs the addendum ships; numbers pass through (the TTS engine reads
/// "42"). `−` is the true minus U+2212 — never ASCII `-`, which would make
/// the lookup miss and the engine read "hyphen".
const _kMathSpeak = <AppLanguage, Map<String, String>>{
  AppLanguage.en: {
    '+': 'plus',
    '−': 'minus',
    '×': 'times',
    '÷': 'divided by',
    '=': 'equals',
    '<': 'is less than',
    '>': 'is greater than',
  },
  AppLanguage.cs: {
    '+': 'plus',
    '−': 'mínus',
    '×': 'krát',
    '÷': 'děleno',
    '=': 'rovná se',
    '<': 'je menší než',
    '>': 'je větší než',
  },
  AppLanguage.uk: {
    '+': 'плюс',
    '−': 'мінус',
    '×': 'помножити на',
    '÷': 'поділити на',
    '=': 'дорівнює',
    '<': 'менше ніж',
    '>': 'більше ніж',
  },
};

/// Translates a composed math string into speakable words. Glyph tokens map
/// to their word; numbers pass through untouched (the engine reads "42",
/// "3.5"). Applied to the composed string only in math mode, right before
/// `SpeechService.speak`.
String mathSpeak(String text, AppLanguage lang) {
  final map = _kMathSpeak[lang] ?? _kMathSpeak[AppLanguage.en]!;
  return text
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => map[t] ?? t)
      .join(' ');
}

/// Appends a digit (or `.`) so a trailing number stays ONE tile:
/// `'' + '4' → '4'`, `'4' + '2' → '42'`, `'3.' + '5' → '3.5'`, and a fresh
/// start after an operator: `'3 + ' + '4' → '3 + 4'`.
String mathAppendDigit(String text, String d) {
  if (text == '') return d;
  if (RegExp(r'[0-9.]$').hasMatch(text)) return text + d;
  if (RegExp(r'\s$').hasMatch(text)) return text + d;
  return '$text $d';
}

/// Appends an operator/comparison as its own space-delimited tile. Never
/// leads with a sign: an empty buffer (or trailing-whitespace-only buffer)
/// is returned unchanged.
String mathAppendOp(String text, String op) {
  final t = text.replaceFirst(RegExp(r'\s+$'), '');
  if (t.isEmpty) return '';
  return '$t $op ';
}

/// Deletes one glyph: trims a digit off a trailing number, or drops a whole
/// sign tile. Mirrors the POC's
/// `text.replace(/\s+$/, '').slice(0, -1).replace(/\s+$/, '')`.
String mathDeleteLast(String text) {
  var t = text.replaceFirst(RegExp(r'\s+$'), '');
  if (t.isEmpty) return '';
  t = t.substring(0, t.length - 1);
  return t.replaceFirst(RegExp(r'\s+$'), '');
}
