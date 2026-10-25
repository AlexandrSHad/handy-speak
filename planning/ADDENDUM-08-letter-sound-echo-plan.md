# HandySpeak — ADDENDUM-08: Letter-sound echo

## Context

Typing feedback (ADDENDUM-era logoped request, `SpeechFeedbackController`)
today echoes each tapped letter key as its **letter name** — tapping `b`
speaks "bee". Two follow-ups were investigated and grilled into this plan:

1. Say the letter's **sound** (/b/, "buh") instead of its name.
2. Speak the echo **slower**, because letter names at the engine's default
   rate feel very fast.

Investigation findings that shaped the design:

- **Android TTS has no phoneme API.** `flutter_tts` / the platform engines
  expose no IPA/phoneme input; SSML `<phoneme>` is unreliable-to-ignored on
  Android engines. The workable technique (standard in phonics/literacy
  apps) is a **per-language letter → "sound spelling" table** — crafted
  text that makes the engine produce the isolated sound ("buh", "sss").
  The repo already has the exact pattern: `lib/core/math_speak.dart`
  (`mathSpeak()`, a per-`AppLanguage` glyph→word map consulted before
  speaking).
- **The rate question may be self-solving.** Letter names are clipped
  one-syllable utterances; sound spellings ("buh", "sss") are naturally
  longer at the same engine rate. Decision: ship sounds at the default
  rate, keep slower rate as a pre-agreed fallback (see Deferred).

Unlike ADDENDUM-01…07 there is **no design handoff** — this plan's design
source is the grilling session recorded below plus the codebase
investigation.

### Decisions taken during the grilling session that produced this plan

- **Hard replacement, no new toggle.** The existing "Read letters while
  typing" toggle (`SettingsController.speakLetters`) changes behavior in
  place: letters now echo their **sounds**. Rationale: the app is not in
  prod (no migration concern), settings must stay lean, and the logoped
  drives the pedagogy. Escape hatch if a names-stage child ever needs
  names: add a toggle then (bool, default on) — cheap, not built now.
- **Mixed echo is deliberate.** One toggle, two regimes: letters → sounds;
  digits → number names; math operators → `mathSpeak` words. Digits and
  operators are *out of scope* for sound treatment. Nobody should later
  "fix" this asymmetry — it is this decision.
- **All three language tables** (en/cs/uk) ship together; the logoped
  prioritizes validating the language(s) the child actually uses. App is
  pre-prod: drafts ship without a review gate, logoped validates in the
  normal feedback loop.
- **Rate: deferred entirely.** No rate code ships. Rate `0.5` is the
  pre-agreed fallback (scope: the three `speakLetters`-gated echo paths —
  letter echo, math digit echo, operator echo), triggered only if the ear
  pass / logoped still reports "too fast" after sounds land. The
  engine-global-rate gotcha is recorded in Deferred for whoever implements
  it.
- **Fallback: unmapped char → speak the raw char** (today's behavior).
  Graceful degradation, no silent keys. This is also exactly how digits
  keep their number names: they simply have no table entries.
- **Settings copy updated** to say what the child hears: the
  `settingsSpeakLettersName`/`…Desc` strings change in all three ARBs.
  Key names stay — only values change, so no `settings_dialog.dart` code
  change.
- **One variable at a time.** Sounds ship alone; the ear pass judges
  speed on the *new* sounds, not on the old names.

### Codebase facts that matter

- `SpeechFeedbackController._onComposerEvent` gates three echo paths on
  `_settings.speakLetters`: `CharTyped` (any keyboard key not in
  `kWordTerminators` — **including the digit row** on en/uk layouts),
  `MathDigitTyped`, and the `MathOpTyped` fallback (operator word via
  `mathSpeak`). Only the `CharTyped` **letter** text changes; digits fall
  through the new table's miss → raw char → engine says "five".
- `WordAppended` (symbols), `TextLoaded` (phrases), and the
  `speakWords`-gated completed-word echoes are untouched.
- Lookup language is the **active** language (`LanguageController.language`),
  exactly like `mathSpeak` today; keyboard shown matches the active
  language.
- Nothing anywhere passes `rate` today (moods are off), so deferring rate
  means zero rate plumbing and zero behavioral risk from
  `setSpeechRate`'s engine-global statefulness.
- ADDENDUM-07: feedback utterances never start `tts/speak` transactions —
  unchanged. `TelemetryService.registerUtterance` will now receive sound
  spellings instead of letter names; redaction semantics treat any text
  as secret, so nothing changes there.
- Big-letters mode (ADDENDUM-01) is display-only ("speech is unchanged"),
  but the lookup lowercases defensively anyway.

## Implementation steps

### 1. `lib/core/letter_sounds.dart` — the table

New file, sibling of `math_speak.dart` (spoken-word map consulted before
speaking → `lib/core/`, not `lib/data/`). Shape:

```dart
/// Isolated-sound spellings for letter keys (ADDENDUM-08). Returns null
/// for unmapped chars (digits, ʼ, ь, anything unknown) — callers fall
/// back to speaking the raw char. DRAFTS: tuned by ear on the reference
/// device, validated by the logoped; the table is the tuning surface.
String? letterSound(String char, AppLanguage lang) { … }

// Private like `_kMathSpeak` — the public API is `letterSound()` only;
// tests (incl. layout-derived coverage) go through the function.
const _kLetterSounds = <AppLanguage, Map<String, String>>{ … };
```

Lookup lowercases the char first.

**Drafting heuristic** (per language, then tuned by ear):
- *Vowels*: identity spelling where the letter name already is the sound
  (cs/uk true by orthography; en needs schwa-ish approximations — weakest
  drafts, logoped to vet).
- *Continuants* (fricatives, nasals, liquids): doubled spelling sustains
  the sound ("sss", "mm").
- *Stops and affricates*: cannot be isolated without a trailing vowel —
  English phonics convention uses schwa ("buh"); Czech/Ukrainian start as
  identity drafts and get ear-pass alternatives only if the engine reads
  them as letter names.

**Draft tables** (spelling choices are initial drafts, not decisions):

```dart
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
  // Stops/affricates: identity drafts — see ear-pass note below.
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
  // Stops/affricates: identity drafts — see ear-pass note below.
  'б': 'б', 'г': 'г', 'ґ': 'ґ', 'д': 'д', 'к': 'к', 'п': 'п', 'т': 'т',
  'ц': 'ц', 'ч': 'ч',
  // Deliberately unmapped (no standalone sound): ь, ʼ — fallback speaks
  // the raw char; flagged for the logoped (maybe silence later).
},
```

Identity entries are intentional even where they equal today's behavior:
they pin per-letter coverage in tests and make "which letters say sounds"
explicit per language, instead of implicit in what's missing.

### 2. `lib/state/speech_feedback_controller.dart` — one-line wiring

In the `CharTyped` branch (the `speakLetters` echo path only):

```dart
} else if (_settings.speakLetters &&
    !kWordTerminators.contains(char)) {
  _say(letterSound(char, _language.language) ?? char);
}
```

Digits on the en/uk number rows, `ʼ`, `ь`, and any miss fall through to
the raw char. All other branches untouched.

Two bookkeeping items land in this same commit:

- Existing name-echo assertions flip to spellings (tap `a` → `'ah'` in
  en) in `test/unit/state/speech_feedback_test.dart` and
  `test/behavior/speech_feedback_test.dart`.
- The controller class dartdoc still says keys "echo its name" — update
  it to sounds.

### 3. Strings — `lib/l10n/app_en.arb`, `app_cs.arb`, `app_uk.arb`

Same keys, new values (then `puro flutter gen-l10n`; generated files are
committed). No widget changes — `settings_dialog.dart` reads the
generated getters.

- EN: name "Say letter sounds while typing"; desc "Each letter is spoken
  as its sound — b says „buh“. Numbers and math signs keep their names."
- CS: name "Říkat hlásky při psaní"; desc "Každé písmeno zazní jako
  hláska (b jako „b“); čísla a znaménka se ozývají svými názvy."
- UK: name "Вимовляти звуки літер під час письма"; desc "Кожна літера
  озвучується як звук (б — як «б»); цифри та знаки вимовляються своїми
  назвами."

### 4. Suite — `handyspeak-suites` convention

Feature tests in the current unit/behavior shape (the per-feature
`integration_test/` pair convention is retired — the device smoke is the
only `integration_test/` consumer):

- Table tests → new `test/unit/core/letter_sounds_test.dart` (sibling of
  `math_speak_test.dart`).
- Controller policy tests → extend
  `test/unit/state/speech_feedback_test.dart`.
- Real-keyboard wiring tests → extend
  `test/behavior/speech_feedback_test.dart`.

No new `integration_test/` pair, no device-smoke change: a device
assertion could only re-check the string FakeTts already proves; engine
pronunciation is the ear pass's job.

## Commit sequence

1. `lib/core/letter_sounds.dart` + table unit tests
   (`test/unit/core/letter_sounds_test.dart`) — data only, nothing calls
   it yet; `puro flutter analyze` + `puro flutter test` green.
2. Controller wiring + tests — the behavior change lands (extend the two
   `speech_feedback` suites; flip their name-echo assertions to
   spellings; update the controller dartdoc — see step 2).
3. ARB strings + `puro flutter gen-l10n` — copy matches behavior.

Then the manual ear pass on the reference device — the acceptance step
for the tables (see Verification). No automated device suite.

## Risks

- **Engine reads isolated letters as names anyway** (the risk behind every
  cs/uk stop-identity draft: "b" alone may come out "bé"/"бе").
  Mitigation: the table is data-only; ear-pass alternatives are cheap
  (doubled spelling, schwa/CV syllable — the logoped picks the method:
  pure sounds vs Czech `slabikování`-style syllables).
- **Cross-engine variance** (Google vs Samsung vs anything preinstalled):
  spellings are tuned on the reference device only; the addendum's answer
  is engine sensitivity is accepted, one reference engine per the ear
  pass, revisit with field reports.
- **English vowel approximations are the weakest drafts** ("ah" for /æ/
  etc.) — flagged for the logoped; expect iteration.
- **Spellings that read as real words** ("uh", "awe", "buh"): the engine
  pronounces the word, which is the intent — verify by ear, not by
  assumption.
- **Pedagogical**: one "primary" sound per letter (en `c`/`x`/`y`, uk
  polyphonic contexts) is a simplification the logoped must bless.

## Verification

**Unit tests (headless):**
- Table suite (`test/unit/core/letter_sounds_test.dart`):
  - Coverage, **derived from `kKeyboardLayouts`**: every letter key of
    every language's layout maps non-null via `letterSound` except the
    explicitly-unmapped set (`ʼ`, `ь`) — no accidental gaps.
  - No digit key in any table (pins the mixed-echo decision).
  - Case normalization: `B` → same entry as `b`.
  - Fallback: `letterSound('5', _)`, `letterSound('ʼ', uk)`, unknown
    chars → null.
- Controller (`test/unit/state/speech_feedback_test.dart` + wiring in
  `test/behavior/speech_feedback_test.dart`): letter key →
  `_say(sound)`; digit key → `_say('5')`; `speakLetters` off → nothing;
  word/symbol/phrase paths unchanged (rate never passed —
  `speak(…, feedback: true)` only).

**Device: no automated suite.** A device assertion could only re-check
the string FakeTts already proves; engine pronunciation is the ear
pass's job (below).

**Manual ear pass (the acceptance step for the tables):** on the
reference device (`puro flutter run`), listen to every letter of every
language the child uses at default rate; adjust spellings in
`letter_sounds.dart`; re-listen. Also spot-check fallbacks (`ʼ`, `ь`,
digits) and the settings copy in all three locales. Rate A/B is
**deferred** — judge speed on the new sounds first; only if still too
fast, open the Deferred item.

## Deferred (explicitly out of scope)

- **Slower echo rate.** Fallback value `0.5` (Android semantics: 1.0 =
  normal). Scope if triggered: the three `speakLetters`-gated echo paths
  only (letter echo, math digit echo, operator echo) — word/symbol/phrase
  echoes stay at engine default. **Gotcha for the implementer:**
  `setSpeechRate` is engine-global and `SpeechService.speak` only applies
  `rate` when non-null — a slow feedback utterance would leak into the
  next main-channel Speak unless every utterance re-applies its intended
  rate. iOS note: flutter_tts rate is not normalized across platforms
  (iOS default 0.5) — hide the constant behind a platform-aware helper
  when iOS lands.
- **Names-mode toggle** (escape hatch for a names-stage child).
- **Per-letter rate overrides** (e.g. shorter sustain for "sss").
- **Sound treatment for digits/operators** — stays names/words by
  decision.
- **`ʼ`/`ь` echo content** — raw char today; logoped may want silence.

## Critical files

- `lib/core/letter_sounds.dart` (new)
- `lib/state/speech_feedback_controller.dart`
- `lib/l10n/app_en.arb`, `app_cs.arb`, `app_uk.arb` (+ generated
  `app_localizations*.dart`)
- `test/unit/core/letter_sounds_test.dart` (new)
- `test/unit/state/speech_feedback_test.dart` (extended)
- `test/behavior/speech_feedback_test.dart` (extended)
