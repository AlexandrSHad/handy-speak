import 'app_language.dart';

/// Isolated-sound spellings for letter keys (ADDENDUM-08). Returns null
/// for unmapped chars (digits, `ʼ`, `ь`, anything unknown) — callers fall
/// back to speaking the raw char. DRAFTS: tuned by ear on the reference
/// device, validated by the logoped; the table is the tuning surface.
String? letterSound(String char, AppLanguage lang) {
  final map = _kLetterSounds[lang] ?? _kLetterSounds[AppLanguage.en]!;
  return map[char.toLowerCase()];
}

// Private like `_kMathSpeak` — the public API is `letterSound()` only;
// tests (incl. layout-derived coverage) go through the function.
//
// Drafting heuristic (per language, then tuned by ear):
// - Vowels: identity spelling where the letter name already is the sound
//   (cs/uk true by orthography; en uses schwa-ish approximations — weakest
//   drafts, logoped to vet).
// - Continuants (fricatives, nasals, liquids): doubled spelling sustains
//   the sound ("sss", "mm").
// - Stops and affricates: cannot be isolated without a trailing vowel —
//   English phonics convention uses schwa ("buh"); Czech/Ukrainian start
//   as identity drafts and get ear-pass alternatives only if the engine
//   reads them as letter names.
//
// Identity entries are intentional even where they equal the old behavior:
// they pin per-letter coverage in tests and make "which letters say
// sounds" explicit per language, instead of implicit in what's missing.
const _kLetterSounds = <AppLanguage, Map<String, String>>{
  AppLanguage.en: {
    'a': 'ah', 'b': 'buh', 'c': 'kuh', 'd': 'duh', 'e': 'eh', 'f': 'fff',
    'g': 'guh', 'h': 'huh', 'i': 'ih', 'j': 'juh', 'k': 'kuh', 'l': 'lll',
    'm': 'mmm', 'n': 'nnn', 'o': 'awe', 'p': 'puh', 'q': 'kwuh', 'r': 'rrr',
    's': 'sss', 't': 'tuh', 'u': 'uh', 'v': 'vvv', 'w': 'wuh', 'x': 'ks',
    'y': 'yuh', 'z': 'zzz',
  },
  AppLanguage.cs: {
    // Vowels and vowel-length diacritics: identity — the Czech letter name
    // already is the sound.
    'a': 'a', 'e': 'e', 'i': 'i', 'o': 'o', 'u': 'u', 'y': 'y',
    'á': 'á', 'é': 'é', 'í': 'í', 'ó': 'ó', 'ú': 'ú', 'ů': 'ů', 'ý': 'ý',
    'ě': 'ě',
    // Single-letter prepositions: the engine reads them as words = pure
    // sounds.
    'k': 'k', 's': 's', 'v': 'v', 'z': 'z',
    // Continuants: doubled spelling.
    'f': 'ff', 'h': 'hh', 'l': 'll', 'm': 'mm', 'n': 'nn', 'r': 'rr',
    // w: foreign letter (Czech "dvojité vé") pronounced [v] — continuant
    // doubling applies; ear-pass draft.
    'w': 'vv',
    // Stops/affricates: identity drafts — engine may read them as letter
    // names; ear pass decides (see plan Risks).
    'b': 'b', 'c': 'c', 'č': 'č', 'd': 'd', 'ď': 'ď', 'g': 'g', 'j': 'j',
    'p': 'p', 'q': 'q', 'ř': 'ř', 'š': 'š', 't': 't', 'ť': 'ť', 'ň': 'ň',
    'x': 'x', 'ž': 'ž',
  },
  AppLanguage.uk: {
    // Vowels: identity — names are the sounds (including iotated є ї ю я).
    'а': 'а', 'е': 'е', 'и': 'и', 'і': 'і', 'ї': 'ї', 'о': 'о', 'у': 'у',
    'є': 'є', 'ю': 'ю', 'я': 'я',
    // Single-letter words: pure sounds.
    'в': 'в', 'з': 'з',
    // Continuants: doubled spelling.
    'ж': 'жж', 'й': 'й', 'л': 'лл', 'м': 'мм', 'н': 'нн', 'р': 'рр',
    'ф': 'фф', 'х': 'хх', 'с': 'сс', 'ш': 'шш',
    // Affricate with a real spelling basis: щ = шч.
    'щ': 'шч',
    // Stops/affricates: identity drafts — engine may read them as letter
    // names; ear pass decides (see plan Risks).
    'б': 'б', 'г': 'г', 'ґ': 'ґ', 'д': 'д', 'к': 'к', 'п': 'п', 'т': 'т',
    'ц': 'ц', 'ч': 'ч',
    // Deliberately unmapped (no standalone sound): ь, ʼ — fallback speaks
    // the raw char; flagged for the logoped (maybe silence later).
  },
};
