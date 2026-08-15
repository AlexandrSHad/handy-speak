# HandySpeak — Addendum 03: Ukrainian layout + language pair

## Context

Derived from `handoff/ADDENDUM-03 Ukrainian layout + language pair.md` and
the current `handoff/HandySpeak-handoff.zip` (POC source: `POC-source/i18n.jsx`,
`tablet.jsx`, `app.jsx`). **The checked-in `handoff/_extracted/` folder is
stale** (dated before Addendum 02 even existed — no `uk`/Cyrillic content in
it) — the zip must be freshly extracted to get real Ukrainian source data.
Scope, verbatim from the addendum: **three features + one bugfix, nothing
else** — (1) Ukrainian locale (keyboard + full UI/vocabulary), (2)
parent-chosen base/second language pair replacing the hardcoded toggle, (3)
per-language voice-pack warnings in Settings, (4) missing a11y labels.

**Decisions from grilling, binding for this plan:**
- Language identifiers use the real ISO 639-1 code throughout: `uk`, not
  `ua` (needed for `flutter_tts` voice matching and Flutter's ICU/CLDR
  plural-rule lookup).
- `AppLanguage`-conditional code converts from binary ternaries to
  exhaustive switch expressions; `Pictogram`/`SymbolCategory` widen from
  `en`/`cs` fields to `en`/`cs`/`uk` required fields — not a runtime `Map`,
  so every one of the ~90 literals is a compile error until supplied.
  Recorded as `docs/adr/0001-nary-language-model.md`.
- No persisted-settings migration — pre-launch, replace the schema outright.
- Voice-pack check uses `getVoices()` (verified against installed
  `flutter_tts` 4.2.5 source: it works on web too, via the browser's
  `SpeechSynthesis.getVoices()` — the package doc comment claiming
  "Android/iOS/macOS only" is stale). No native "voice list changed" event
  exists on any platform, so: check once when Settings opens, plus a manual
  refresh button — no polling/timer.
- Single combined effort, one plan, one commit sequence — mirrors Addendum
  02.
- Deferred items (single-language mode, uk prediction table, >2-language
  pairs, BETA badge, UI/typing split) stay explicitly out.

**Gaps found vs. the addendum (Phase 1 alignment):**
- **Snap & Say doesn't exist in this Flutter app** (grepped — no matches
  anywhere in `lib/`). The addendum's bugfix items for its close button /
  shutter `aria-label` are **N/A**, skipped.
- The addendum's `aria-label="Language"` bugfix assumes a hardcoded English
  string to fix. This Flutter app's top-bar language toggle has **no label
  at all today** — so this is "add a missing label," not "fix a hardcoded
  one." Same functional outcome, different framing.
- The Settings sheet's close `IconButton` (`settings_sheet.dart:60-63`) also
  has no accessible label — genuinely in scope for the `closeLabel` bugfix
  even without Snap & Say.
- `captureLabel` (shutter) has no applicable surface — **N/A**, skipped.

**Key codebase facts:**
- `AppLanguage` (`lib/core/app_language.dart`) is `enum {en, cs}` with
  binary ternaries at lines 14/17/20/26. Other binary-ternary sites:
  `pictograms.dart:12`, `categories.dart:15`, `settings_sheet.dart:188`,
  `speech_service.dart:41-42,79-80`.
- Already table-driven (map-keyed, add-a-`uk`-entry-only):
  `keyboard_layouts.dart`, `phrases_data.dart`, `math_speak.dart`,
  `phrases_controller.dart` (loops `AppLanguage.values`).
- `LanguageController.setLanguage` (`language_controller.dart:33`) takes any
  `AppLanguage` directly — no toggle/pair concept exists today. Persisted
  key: single `'language'` string.
- `TopBar._LanguageToggle` (`top_bar.dart:190`) loops `AppLanguage.values` —
  would silently render 3 pills without Feature 2.
- `SettingsSheet._LanguageSection` (`settings_sheet.dart:122-193`) is
  currently "pick the active language from all values," not a base/second
  picker — needs full replacement, including the `speech.csAvailable`-gated
  `NoticeBanner` at line 188.
- `SpeechService.csAvailable`/`enAvailable` (`speech_service.dart:41-42`)
  are soft, init-only signals via `isLanguageAvailable` — explicitly
  documented as unable to distinguish "engine supports it" from "voice pack
  installed," which is exactly the gap Feature 3 closes. These get
  replaced, not extended.
- No custom font in `theme.dart` — system default. Czech diacritics (Latin
  Extended) already work; Cyrillic is untested by precedent but low-risk
  (system fonts on Android/Chrome cover Ukrainian Cyrillic, including
  ґ/є/і/ї). Verify visually, not an architecture concern.
- `keyboard_view.dart`'s `123`/`ABC` toggle is driven by `hasNumRow`
  (`rows.any((r) => r.type == KbRowType.number)`), already generic — a `uk`
  layout with a digit row (`KbRowType.number`) gets "no `123` key" for free,
  no new branching needed.

## Implementation steps

### 1. `lib/core/app_language.dart`
Widen to `enum { en, cs, uk }`. Convert every ternary to a switch
expression:
```dart
String get ttsLocale => switch (this) {
  AppLanguage.en => 'en-US',
  AppLanguage.cs => 'cs-CZ',
  AppLanguage.uk => 'uk-UA',
};
String get short => switch (this) { en => 'EN', cs => 'CZ', uk => 'UK' };
String get nativeName => switch (this) { en => 'English', cs => 'Čeština', uk => 'Українська' };
static AppLanguage fromKey(String? key) => switch (key) {
  'cs' => AppLanguage.cs, 'uk' => AppLanguage.uk, _ => AppLanguage.en,
};
```
No new `voicePrefix` field — `.key` (already `en`/`cs`/`uk`) is reused
directly for voice-locale-prefix matching in step 6, avoiding a redundant
identical field.

### 2. `lib/data/pictograms.dart`, `lib/data/categories.dart`
Add a required `uk` field to `Pictogram`/`SymbolCategory`; convert
`word()`/`label()` to switch expressions. Port all 80 pictogram + 8
category Ukrainian labels verbatim from the zip's `POC-source/i18n.jsx`
`WORDS_UK`/`CATS_UK` — do not hand-translate.

### 3. `lib/data/keyboard_layouts.dart`
Add the `uk` entry:
```dart
AppLanguage.uk: [
  KbRow(['1','2','3','4','5','6','7','8','9','0'], KbRowType.number),
  KbRow(['й','ц','у','к','е','н','г','ш','щ','з','х','ї']),
  KbRow(['ф','і','в','а','п','р','о','л','д','ж','є','ґ']),
  KbRow(['я','ч','с','м','и','т','ь','б','ю','ʼ']),
],
```
No changes needed in `keyboard_view.dart` — `hasNumRow` already suppresses
the `123` toggle generically, big-letters/shift already Unicode-aware via
`toUpperCase()`.

### 4. `lib/data/phrases_data.dart`
Add `AppLanguage.uk: [...]` — port `PHRASES_UK` verbatim from the POC.

### 5. `lib/core/math_speak.dart`
Add the `uk` column exactly as specified in the addendum (plus «дорівнює»,
«менше ніж», «більше ніж» etc. — not present in the POC, addendum gives the
literal translations).

### 6. `lib/services/speech_service.dart`
Remove `csAvailable`/`enAvailable`. Add:
```dart
Future<bool> hasVoiceFor(AppLanguage lang) async {
  if (!isReady) return true; // don't false-warn before we can check
  try {
    final voices = await _tts.getVoices;
    if (voices is! List) return true;
    return voices.any((v) => (v as Map)['locale']
        ?.toString().toLowerCase().startsWith(lang.key) ?? false);
  } catch (_) {
    return true; // fail open, never show a false warning from a check error
  }
}
```

### 7. `lib/state/language_controller.dart`
Add `baseLang`/`secondLang` state, persisted under new keys
`base_lang`/`second_lang` (default `en`/`cs`). `setBaseLang`/`setSecondLang`
swap the pair symmetrically and snap the active language to base by
delegating to the existing `setLanguage` (reuses its full side-effect path —
stop speech, clear sentence, set TTS locale — instead of duplicating it):
```dart
void setBaseLang(AppLanguage next) {
  if (next == _baseLang) return;
  if (next == _secondLang) _secondLang = _baseLang;
  _baseLang = next;
  _persistPair();
  if (!pair.contains(_language)) { setLanguage(_baseLang); return; }
  notifyListeners();
}
// setSecondLang mirrors this.
List<AppLanguage> get pair => [_baseLang, _secondLang];
```

### 8. `lib/widgets/top_bar.dart`
`_LanguageToggle`: replace `for (final l in AppLanguage.values)` with
`for (final l in context.watch<LanguageController>().pair)`. Wrap the
toggle's outer `Container` in `Semantics(label: l10n.settingsLanguage, child: ...)`
(bugfix — reusing the existing "Language" string, no new key).

### 9. `lib/widgets/settings_sheet.dart`
Replace `_LanguageSection` entirely: two picker lists (Base/Second), each
offering all of `AppLanguage.values`, calling `setBaseLang`/`setSecondLang`.
Becomes a `StatefulWidget` that calls `SpeechService.hasVoiceFor` for both
slots on `initState` and on pair change (mirror the listener pattern already
used for `_numOpen` in `keyboard_view.dart:41-59`), plus a manual refresh
icon that re-runs the same check. Each slot renders its own `NoticeBanner`
using `voiceMissingNamed`. Add `tooltip: l10n.closeLabel` to the sheet's
close `IconButton` (line 62, bugfix).

### 10. `lib/l10n/app_en.arb`, `app_cs.arb`, new `app_uk.arb`
- Update `settingsLanguageDesc` value (both langs) to the addendum's new
  pair-aware copy.
- Add `settingsBaseLangName`/`Desc`, `settingsSecondLangName`/`Desc`
  (following this codebase's existing `settings<Feature>Name`/`Desc`
  convention, not the addendum's literal `setBaseLang` naming).
- Add `voiceMissingNamed` (with `{lang}` placeholder); **remove**
  `voiceMissing` (dead once per-slot warnings replace the single
  Czech-only one).
- Add `closeLabel`. Skip `captureLabel` (N/A, no Snap & Say surface).
- `wordCount` for `uk`, using real CLDR Ukrainian categories (verified
  against the addendum's acceptance criteria: 1→one, 2-4→few, 5-10→many,
  11→many, 21→one, 22→few):
  `"{count, plural, =0{0 слів} one{{count} слово} few{{count} слова} many{{count} слів} other{{count} слів}}"`
- Full `uk` UI table for every other key, ported verbatim from
  `POC-source/i18n.jsx` (mapping POC key names to this codebase's renamed
  keys where they differ).
- Run `flutter gen-l10n`; commit regenerated `app_localizations*.dart`.

## Commit sequence
1. `AppLanguage` widening + switch conversion (step 1) — additive, compiles
   once steps 2-5 supply the new `uk` data everywhere the compiler now
   demands it.
2. Data ports: pictograms, categories, keyboard layout, phrases, math_speak
   (steps 2-5) + `app_uk.arb` (step 10) — the app now fully supports `uk`
   as a directly-selectable language, still behind the old single-language
   UI.
3. `SpeechService.hasVoiceFor` (step 6) — additive, unused until step 9.
4. `LanguageController` base/second pair (step 7) — the persistence/model
   layer for Feature 2.
5. `TopBar` + `SettingsSheet` wiring (steps 8-9) — Feature 2 and Feature 3
   become visible/usable together, plus the bugfix.
6. Tests (see Verification) interleaved with each step, test-first per
   project convention.

`flutter analyze` after each step.

## Risks
- **Silent ICU plural fallback**: if `app_uk.arb`'s `@@locale` or filename
  doesn't match a real CLDR-known code, `intl` could silently pick generic
  plural rules instead of Ukrainian's — must stay `uk`.
- **Hand-porting the POC's Ukrainian vocabulary wrong**: 80 pictograms + 8
  categories + full UI table is a lot of copy-paste; a transcription slip
  is easy to miss. Mitigate by diffing key-by-key against
  `POC-source/i18n.jsx`, not retyping from the addendum's prose.
- **`getVoices()` shape assumptions**: the addendum's POC used the
  browser's voice list shape; the Android/iOS native return might differ
  enough that `(v as Map)['locale']` throws — caught by the existing
  `catch (_) => true` fail-open, but worth an explicit unit test with a
  mocked shape.
- **Missed switch-expression conversion site**: any leftover ternary on
  `AppLanguage` silently mishandles `uk` — `flutter analyze` won't catch a
  ternary (only an actual `switch` is exhaustiveness-checked), so this
  needs a manual grep pass for `AppLanguage.cs ?` / `== AppLanguage.cs`
  before considering the feature done.
- **Snap-to-base double-notify**: `setBaseLang`/`setSecondLang` calling
  `setLanguage` internally must not also call `notifyListeners()` again on
  that path (redundant but harmless — still worth getting right, asserted
  in the controller unit test).

## Verification

**Unit tests:**
- `AppLanguage` switch coverage for all 3 values (ttsLocale/short/nativeName/fromKey).
- `LanguageController`: base/second swap-on-conflict, snap-to-base on
  orphaning, persistence round-trip.
- `mathSpeak` uk column, all 7 glyphs.
- `SpeechService.hasVoiceFor` with mocked `getVoices()` shapes
  (present/absent/malformed).
- `wordCount` uk plural boundaries: 0, 1, 2, 4, 5, 10, 11, 12, 14, 21, 22.

**Integration tests** (new `integration_test/addendum03_suite.dart` +
headless `test/addendum03_test.dart`, mirroring Addendum 01/02 shape):
third-language keyboard renders correctly with no `123` key; apostrophe
stays one word tile; big-letters uppercases Cyrillic; top-bar shows exactly
2 pills matching the pair; Settings pickers swap correctly; voice warning
shows/hides per slot with mocked `flutter_tts`; Settings close button has a
label.

**Manual checks (Chrome, since no reliable Android device locally — per
project memory; avoid manual checks where automatable):**
- Visual Cyrillic rendering (font coverage, especially ʼ/ґ/є/і/ї) — not
  unit-testable.
- Golden test for the uk keyboard board, gated on visual sign-off — same
  pattern as Addendum 02's math board golden, added only after visual
  sign-off.

## Critical files
- `lib/core/app_language.dart`
- `lib/data/pictograms.dart`
- `lib/data/categories.dart`
- `lib/data/keyboard_layouts.dart`
- `lib/data/phrases_data.dart`
- `lib/core/math_speak.dart`
- `lib/services/speech_service.dart`
- `lib/state/language_controller.dart`
- `lib/widgets/top_bar.dart`
- `lib/widgets/settings_sheet.dart`
- `lib/widgets/keyboard_view.dart` (no code change expected, verify only)
- `lib/l10n/app_en.arb`, `app_cs.arb`, new `app_uk.arb` (+ generated
  `app_localizations*.dart`)
- `test/addendum03_test.dart` (new)
- `integration_test/addendum03_suite.dart`, `addendum03_test.dart` (new)
