# HandySpeak — Addendum 02: Math board + Inline numbers

## Context

Derived from `handoff/ADDENDUM-02 Math board + inline numbers.md` and the
regenerated `handoff/HandySpeak-handoff.zip` (POC source:
`tablet.jsx`, `word-blocks.jsx`, `i18n.jsx`, `styles.css`). The addendum's
stated scope is **three features and nothing else**:

1. **Math mode** — a third input board (a *voice* for math, **never a
   calculator**: no evaluation, no result, `=` is a plain peer key). One
   aligned 4×5 grid; consecutive digits group into one message tile, each
   operator/comparison is its own tile; Speak voices glyphs as words.
2. **Inline numbers on the keyboard** — English already has a digit row
   (no change); Czech reveals `0–9` by **swapping the diacritics row in
   place** behind a `123`/`ABC` toggle.
3. **Two message-bar workspaces** — a *sentence* buffer (Keyboard + Symbols)
   and a separate *math* buffer; switching modes is non-destructive; a
   language switch clears only the sentence (math is glyphs and survives).

The addendum explicitly defers: **Advanced math** (`≠ ≤ ≥`), **speak-while
-typing per-key echo**, and **cross-linking the Symbols "Numbers" category**.
Do not implement any of these.

### Guiding framing (drives every decision)
HandySpeak never computes. The math board composes a problem the same way
every other board composes a message; Speak reads the whole problem in
words. `=` never evaluates.

### Decisions resolved during Phase 1 (from the POC, the approved reference)
- **`123` key lives in the bottom space/punctuation row** (`_SpaceRow` in
  this codebase), as its **first** key, shown only when the layout has no
  permanent digit row. The addendum calls this the "bottom modifier row";
  in the POC that row is the `, [space] . ! ?` row with `123` prepended and
  `!`/`?`/`123` all carrying `key mod` styling. Our `_SpaceRow` is the
  direct analog. (Placing it in the shift/backspace letter row would crowd
  9 keys; the POC does not do this.)
- **Swapped Czech digit row gets the teal operator tint** (`op-soft`/`op-ink`,
  POC `.kb-row.num-strip .key.num`) — same row slot as the diacritics, with a
  number-mode tint as an affordance. Reuses the new operator tokens below.
- **`activeIndex` includes math mode** (POC `word-blocks.jsx:23`):
  `(mode === 'keyboard' || mode === 'math')`. The trailing in-progress number
  shows the caret (not removable while typing); completed tiles are
  removable. This is consistent with the addendum's "math tiles edit like
  sentence words."
- **Minus is the true glyph `−` U+2212**, never ASCII `-`. It must be
  identical across the keycap, the stored token, the `MATH_SPEAK` map key,
  and backspace — a stray ASCII `-` silently breaks the spoken-word lookup.
- **`123`/`ABC` are literal glyphs**, not localized strings (the POC
  hardcodes them; they are not translatable). Only two new ARB keys are
  added (`modeMath`, `keyBackspace`), matching the addendum's i18n table.
- **`mathSpeak` map = exactly the 7 glyphs the addendum lists**
  (`+ − × ÷ = < >`). The POC map also has `≠ ≤ ≥` (deferred) and `.`
  (dead — `.` always joins a number token, never stands alone), neither of
  which is implemented.
- **Icon for the Math pill**: `Icons.calculate_outlined` (closest Material
  glyph to the POC's tablet/pad SVG; `Icons.math` does not exist in Flutter).

### Key codebase facts
- **Message bar tokenization is already whitespace-based**
  (`composer_controller.dart`: `tokens` splits on `\s+`). The math
  tokenizer's grouping/own-tile behavior is achieved purely by **how we
  write into the buffer** (digits appended with no space; operators
  appended as ` <op> `). `MessageBlocks`/`MessageBar` need **no change** —
  they render whatever tokens exist. Big-letters `.displayUpper()` is a
  no-op on glyphs/digits, so it composes for free.
- **Single-buffer controller today**: `ComposerController` has one `_text`.
  `clear()` is called by **both** the MessageBar Clear button **and**
  `LanguageController.setLanguage`. The dual-buffer split must distinguish
  these (Clear = active buffer; language switch = sentence buffer only).
- **`flutter_tts` pronounces `× ÷ = < >` unreliably** → translate glyphs to
  words **before** `SpeechService.speak`, only in math mode. Numbers pass
  through (engines read "42" correctly).
- `pubspec.yaml` has `generate: true` → l10n regenerates on build;
  `flutter gen-l10n` for immediate IDE resolution.
- Every content key on the keyboard uses `ForgivingTap` (motor-impaired
  audience — see `docs/forgiving-taps.md`). The math board must too.
- Theme tokens are centralized in `lib/core/theme.dart` ("ALL visual styling
  lives here"); the POC's teal/violet tints have **no existing equivalent**,
  so this plan adds four tokens (the existing `accent` blue is a different,
  already-used semantic and must not be repurposed).

## Implementation steps

### 1. Math color tokens — `lib/core/theme.dart`
Add four tokens per variant (`opSoft`, `opInk`, `relSoft`, `relInk`),
threading each through the constructor, `light`, `dark`, `copyWith`, and
`lerp` exactly like the existing `accent`/`accentSoft` pair. Values are
sRGB conversions of the POC's OKLCH (mirroring the file's existing
"approximate sRGB conversions of the prototype's OKLCH palette" comment):

| token | light | dark | POC OKLCH (L C H) |
|---|---|---|---|
| `opSoft`  | `#C4F3EA` | `#0A3B38` | 93% .05 182 / 32% .05 188 |
| `opInk`   | `#006962` | `#77E0D3` | 46% .10 188 / 84% .10 185 |
| `relSoft` | `#F5E8FF` | `#392B49` | 95% .045 305 / 32% .055 305 |
| `relInk`  | `#764AA2` | `#DDBDFF` | 50% .14 305 / 85% .10 305 |

Operators (`÷ × − +`) use `opSoft`/`opInk`; comparisons (`< > =`) use
`relSoft`/`relInk`.

### 2. Pure math helpers — new `lib/core/math_speak.dart`
Stateless, unit-testable functions ported verbatim from the POC. No Flutter
imports (so tests need no binding).

```dart
import '../core/app_language.dart';

const _kMathSpeak = <AppLanguage, Map<String, String>>{
  AppLanguage.en: {
    '+': 'plus', '−': 'minus', '×': 'times', '÷': 'divided by',
    '=': 'equals', '<': 'is less than', '>': 'is greater than',
  },
  AppLanguage.cs: {
    '+': 'plus', '−': 'mínus', '×': 'krát', '÷': 'děleno',
    '=': 'rovná se', '<': 'je menší než', '>': 'je větší než',
  },
};

/// Glyph tokens → spoken words; numbers pass through (TTS reads "42").
/// Applied to the composed string only in math mode, right before speak().
String mathSpeak(String text, AppLanguage lang) {
  final map = _kMathSpeak[lang] ?? _kMathSpeak[AppLanguage.en]!;
  return text
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => map[t] ?? t)
      .join(' ');
}

/// Digits & `.` join the trailing number so it stays ONE tile ("42").
String mathAppendDigit(String text, String d) {
  if (text == '') return d;
  if (RegExp(r'[0-9.]$').hasMatch(text)) return text + d; // 4 -> 42
  if (RegExp(r'\s$').hasMatch(text)) return text + d;     // already spaced after a sign
  return '$text $d';                                      // start a fresh number
}

/// Operators & comparisons are always their own space-delimited tile;
/// never lead with a sign.
String mathAppendOp(String text, String op) {
  final t = text.replaceFirst(RegExp(r'\s+$'), '');
  if (t == '') return t;
  return '$t $op ';
}

/// Delete one glyph: trim a digit off a number, or drop a whole sign.
String mathBackspace(String text) =>
    text.replaceFirst(RegExp(r'\s+$'), '').substring(0, text.length > 0 ? (text.replaceFirst(RegExp(r'\s+$'), '').length - 1) : 0)
        .replaceFirst(RegExp(r'\s+$'), '');
```
(Implement `mathBackspace` as the POC's
`text.replace(/\s+$/, '').slice(0, -1).replace(/\s+$/, '')`: strip trailing
ws → drop one char → strip trailing ws. Write it readably; the snippet above
is illustrative.)

### 3. l10n — `lib/l10n/app_en.arb` + `app_cs.arb`
Add two keys (naming follows existing conventions: `mode*` for pills,
`key*` for keyboard labels):
- `modeMath`: **"Math"** / **"Počítání"**
- `keyBackspace`: **"Delete"** / **"Smazat"**  (aria-label on the math `⌫`)

Run `flutter gen-l10n`; commit regenerated `app_localizations*.dart`.
(`123`/`ABC` are literal glyphs, not ARB strings — see decisions.)

### 4. Dual-buffer controller — `lib/state/composer_controller.dart`
The largest change. Split the single `_text` into a routed pair, keeping
every existing public signature so `MessageBar`/`MessageBlocks`/`SpeakButton`
keep working unchanged.

- Add `math` to the `InputMode` enum.
- Replace `String _text = '';` with `String _sentenceText = '';` and
  `String _mathText = '';`. Add a routed getter and a private active setter:
  ```dart
  String get text => _mode == InputMode.math ? _mathText : _sentenceText;
  String get _active => _mode == InputMode.math ? _mathText : _sentenceText;
  set _active(String v) {
    if (_mode == InputMode.math) _mathText = v; else _sentenceText = v;
  }
  ```
  Replace every `_text` read with `text` and every `_text =` write with
  `_active =` inside `addChar` / `appendWord` / `loadText` / `removeWordAt` /
  `backspace`. (`tokens`, `wordCount`, `_endsWithSpace` already key off
  `_text` → repoint them to `text`.)
- `activeIndex` — include math (POC parity):
  ```dart
  int get activeIndex =>
      (_mode == InputMode.keyboard || _mode == InputMode.math) &&
              !_endsWithSpace && tokens.isNotEmpty
          ? tokens.length - 1
          : -1;
  ```
- `clear()` now clears the **active** buffer (MessageBar Clear in math wipes
  the problem; in keyboard/symbols wipes the sentence). Add
  `clearSentence()` that wipes `_sentenceText` only — used by language
  switch.
- New math mutators (guard: only meaningful in math mode; route to
  `_mathText` regardless so a stray call can't corrupt the sentence):
  ```dart
  void appendMathDigit(String d) {
    _mathText = mathAppendDigit(_mathText, d);
    notifyListeners();
  }
  void appendMathOp(String op) {
    _mathText = mathAppendOp(_mathText, op);
    notifyListeners();
  }
  void mathBackspace() {
    if (_mathText.isEmpty) return;
    _mathText = mathBackspaceFn(_mathText); // avoid clashing with the public method name
    notifyListeners();
  }
  ```
  (Import `math_speak.dart`; alias the function if the name clashes with the
  method — e.g. `import '../core/math_speak.dart' show mathSpeak, mathAppendDigit, mathAppendOp;`
  and import the backspace helper under a different name, or rename the
  method to `mathDelete`.)
- `setMode` is unchanged (still just flips `_mode` + notifies); the buffer
  routing is derived, so non-destructive switching is automatic.

### 5. Language switch clears only the sentence — `lib/state/language_controller.dart`
Replace `_composer.clear();` in `setLanguage` with
`_composer.clearSentence();`. Update the surrounding comment ("free-typed
prose is language-bound; the math problem is glyphs and survives"). The math
buffer now survives an EN⇄CS switch, matching the addendum.

### 6. Speak voices math glyphs — `lib/widgets/speak_button.dart`
At the single speak call site (~`onPressed`), translate only in math mode:
```dart
final composer = context.read<ComposerController>();
final toSpeak = composer.mode == InputMode.math
    ? mathSpeak(composer.text, context.read<LanguageController>().language)
    : composer.text;
context.read<SpeechService>().speak(toSpeak);
```
Import `math_speak.dart` and `language_controller.dart`. Mood rate/pitch
 plumbing is unchanged (already passes through to `SpeechService.speak`).

### 7. Math board widget — new `lib/widgets/math_board.dart`
A peer of `KeyboardView` / `SymbolBoard`. Stateless; all state lives in
`ComposerController`. Fills the same `Expanded` the home page gives the
active board.

- Layout: a `Column` of **five `Expanded` rows**, each row a `Row` of
  `Expanded` keys. This gives the POC's 4-equal-column / 5-equal-row grid
  exactly, and makes `0` span two columns via `flex: 2` (GridView can't
  easily span; the Row approach mirrors the POC's
  `grid-template-columns: repeat(4,1fr)` + `.zero{grid-column:span 2}`).
  Rows, calculator order:
  ```
  7  8  9  ÷      (flex 1 each)
  4  5  6  ×
  1  2  3  −
  0(flex 2)  .  +
  <  >  =  ⌫      (flex 1 each)
  ```
- A private `_MathKey` widget (modeled on `_CharKey` in `keyboard_view.dart`)
  with `ForgivingTap`, `AppTokens.rKey` radius, 1.5px border, and a `kind`
  that picks the tint:
  - `digit` / `dot` → `colors.keyBg` bg, `colors.ink` text, font 34.
  - `op` → `colors.opSoft` bg, `colors.opInk` text, font 36 (`÷ × − +`).
  - `rel` → `colors.relSoft` bg, `colors.relInk` text, font 32 (`< > =`).
  - `backspace` → `colors.keyMod` bg, `colors.ink2` icon
    (`Icons.backspace_outlined`), `Semantics(label: l10n.keyBackspace)`.
- `onTap` routes by kind: digit/`.` → `appendMathDigit`; op/rel →
  `appendMathOp`; `⌫` → `mathBackspace` (alias `mathDelete`). Haptic via
  `SettingsController.haptics` like the keyboard.
- Watch `bigLetters` and apply `.displayUpper(big)` to keycap text (no-op on
  glyphs/digits, but consistent with the other boards; harmless and greppable).

### 8. Home page routing — `lib/widgets/home_page.dart`
Replace the two-way board switch with a three-way:
```dart
child: switch (mode) {
  InputMode.keyboard => const KeyboardView(),
  InputMode.math => const MathBoard(),
  InputMode.symbols => const SymbolBoard(),
},
```
Add `import 'math_board.dart';`. Everything else (TopBar, MessageBar, phrase
strip, notice banner) is unchanged — the message bar already reads
`composer.text`, which now routes to the right buffer.

### 9. Third mode pill — `lib/widgets/top_bar.dart`
In `_ModeToggle`, add a third `seg` after Symbols:
```dart
seg(InputMode.math, Icons.calculate_outlined, l10n.modeMath),
```
No other change — the existing `setMode` already handles the routing.

### 10. Inline numbers (Czech) — `lib/widgets/keyboard_view.dart`
Feature 2. The toggle and the row swap both live here.

- `_KeyboardViewState`: add `bool _numOpen = false;`.
- In `build`, compute
  `final hasNumRow = rows.any((r) => r.type == KbRowType.number);`
  (English → true; Czech → false). Pass `hasNumRow`, `numOpen: _numOpen`,
  and `onToggleNum: () => setState(() => _numOpen = !_numOpen)` down to the
  relevant rows.
- **Accent-row swap**: when iterating `rows`, if a row is
  `KbRowType.accent` and `_numOpen`, render the digit list
  `['1','2','3','4','5','6','7','8','9','0']` (define a `const _kDigits`)
  instead of the diacritics — same row slot, 10 keys instead of 15 (each
  `Expanded`, so they widen in place; no motion/overlay). Easiest: build a
  synthetic `KbRow(_kDigits, KbRowType.number)` for the swapped row and pass
  it to `_CharRow`. Reuse the existing `_CharKey`.
- **Teal tint on the swapped digit row** (POC `.num-strip`): parametrize
  `_CharKey` with optional `Color? tintBg, Color? tintInk`; the swapped
  digit row passes `colors.opSoft` / `colors.opInk`; the regular rows pass
  null (default `keyBg`/`ink`).
- **`123`/`ABC` toggle**: add it as the **first** child of `_SpaceRow`,
  rendered only when `!hasNumRow`. Style it like `_ModKey` (`keyMod` bg,
  pressed state when `_numOpen`), label `_numOpen ? 'ABC' : '123'` (literal
  glyphs), `onTap` → `onToggleNum`. `_SpaceRow` currently takes only
  `onChar`; add `showNumToggle`, `numOpen`, `onToggleNum` params, threaded
  from `_KeyboardViewState.build`. (No toggle on English — it already has
  the permanent digit row.)
- `_numOpen` should reset to `false` when the language changes (English has
  no toggle, so a stale-open state is meaningless and could surprise on
  switching back to Czech). Simplest: watch `LanguageController` and reset
  in `didUpdateWidget`/build, or key the keyboard off the language. Note in
  PR.

### 11. Tests (test-first for the logic)
- **Unit — `test/math_speak_test.dart`** (no Flutter binding): `mathSpeak`
  EN + CS for all 7 glyphs; numbers pass through (`'42' → '42'`); mixed
  `'12 × 5 ='` → `'twelve…'` is the engine's job, assert tokens become
  `'12 times 5 equals'` / CS `'12 krát 5 rovná se'`; `mathAppendDigit`
  grouping (`'4'+'2'→'42'`), decimal join (`'3'+'.'→'3.'`, then `+'5'→'3.5'`),
  fresh-after-space (`'3 + '+'4'→'3 + 4'`); `mathAppendOp` own-tile
  (`'3'+'+'→'3 + '`) and never-leads-with-sign (`''+'+'→''`);
  `mathBackspace` digit-off-number vs whole-sign
  (`'3 + 4'→'3 + '→'3'`), and minus uses `−` not `-`.
- **Unit — extend `test/` for `ComposerController`** (or a new
  `test/composer_controller_math_test.dart`): Keyboard→Math preserves the
  sentence and restores it on return; Math remembers its problem; `clear()`
  clears the active buffer; `clearSentence()` leaves math intact;
  `setLanguage` (via a fake storage/speech) clears only the sentence;
  `activeIndex` returns the trailing token in both keyboard and math, `-1`
  after a space; Keyboard⇄Symbols share one buffer.
- **Integration/widget suite** — new `integration_test/addendum02_suite.dart`
  + `integration_test/addendum02_test.dart` (device/web entry) and
  `test/addendum02_test.dart` (headless entry), mirroring the ADDENDUM-01
  shared-suite shape exactly (`runAddendum02Suite()`; fake `flutter_tts` and
  `shared_preferences` at the platform-channel level). Cover: third pill
  "Math"/"Počítání" switches to the board (EN + CS); grid renders the true
  glyphs `÷ × − < > =` and `⌫`, with `0` occupying double width; typing
  `4,2` yields one tile `42`; typing `3 + 4 = 7` yields five tiles; `⌫`
  deletes one glyph; math tiles tap-to-✕ remove; Speak in math is called
  with the translated string (`'…times…equals…'`/`'…krát…rovná se…'`); Czech
  shows the `123` key and English does not; tapping `123` swaps the accent
  row to digits; EN⇄CS preserves the math problem and clears the sentence.

### 12. Golden test — `test/math_board_golden_test.dart` (GATED on visual sign-off)
A golden file is a saved reference image; the test re-renders the widget and
**pixel-diffs** against it, failing on any drift. Its only job is to lock in
the approved look, so the baseline must be captured **at the moment the look
is approved** — not before, otherwise an unreviewed render gets frozen as
"known-good".

**Trigger:** do this step only after the user has run the feature on Chrome,
eyeballed the board, and confirmed it looks right. Do not write this test or
generate its baseline during steps 1–11.

Once sign-off is given:
- Add a pure widget test `test/math_board_golden_test.dart` that pumps
  `MathBoard` inside the app theme wrapper (no `flutter_tts` / no integration
  binding — goldens run under `flutter test`).
- Capture **two** baselines — light and dark — because the op/rel tint tokens
differ per brightness. The board is language-neutral (glyphs are identical in
EN/CS), so one locale suffices:
  ```dart
  await expectLater(find.byType(MathBoard),
      matchesGoldenFile('goldens/math_board_light.png'));
  ```
- Generate the PNGs with `flutter test --update-goldens`, then commit **both
  the test and the PNGs** in a single commit so the regression guard is live
  from the first run.
- Keep it isolated from `addendum02_suite.dart` so regenerating the baseline
  (`--update-goldens`) never touches the behavioral suite.

Brittleness is expected and accepted: any later reskin (the theme is
described as approximate and due for a find-and-replace) will flip this test
red — that's the point. Recover with `flutter test --update-goldens` after
re-confirming the new look.

## Commit sequence
1. Tokens + pure math helpers + ARB + gen-l10n (additive, app unchanged) —
   steps 1–3.
2. Dual-buffer `ComposerController` + math mutators + `activeIndex` +
   `LanguageController.clearSentence` (+ unit tests) — steps 4–5.
3. Speak-button mathSpeak wiring — step 6.
4. `MathBoard` + home-page routing + third pill — steps 7–9.
5. Keyboard inline-digits (Czech `123` toggle + accent-row swap) — step 10.
6. Integration/widget suite + headless entry — step 11 (interleave logic
   tests with steps 1–2, test-first).
7. Golden test + baseline PNGs — step 12. **Not part of the feature build**;
   gated on the user's visual sign-off, then captured and committed in one go.

`flutter analyze` after each step.

## Risks
- **Highest: leaking raw glyphs into TTS**, or applying `mathSpeak` outside
  math mode. The single speak call site must branch on `mode == math`. The
  verification checklist asserts the spoken string for both languages.
- **Minus glyph consistency**: `−` (U+2212) must be the literal in
  `math_speak.dart`'s map, the `MathBoard` op key, and any backspace test.
  A stray ASCII `-` makes the lookup miss and the engine read "hyphen". The
  unit test asserts `−` explicitly.
- **Writing the wrong buffer**: a math mutator touching `_sentenceText` (or
  `appendWord`/`addChar` running in math mode) would corrupt a workspace.
  Route all writes through `_active`; guard math mutators to `_mathText`.
- **`clear()` semantics changed**: MessageBar Clear in math now clears math
  (intended). `LanguageController` MUST call `clearSentence()`, not
  `clear()` — otherwise a language switch wipes the math problem, violating
  the addendum. Asserted in the controller unit test.
- **Golden test brittleness** (step 12): the baseline will break on any
  theme reskin or font change — by design. It must only be added *after*
  visual sign-off, and regenerated with `--update-goldens` when the look
  intentionally changes. Do not let a red golden block unrelated work;
  re-confirm and update.
- **Stale `_numOpen` across language switch**: switching EN→CS with
  `_numOpen` left true could show digits with no toggle to leave. Reset on
  language change; note in PR.
- **`0` spanning**: implement via Row `flex: 2`, not GridView (which can't
  cleanly span). Verify the rect width is ~2× a normal key in the widget
  test.
- **Czech swapped row width**: 10 keys vs 15 → each key wider; confirm no
  overflow and tap target ≥ `AppTokens.minTap` (72) at tablet size.
- **Big-letters interaction**: `.displayUpper()` on glyphs/digits is a
  no-op (correct); confirm math keys don't visually change under Big
  letters.
- **Gamut of the new tints**: the sRGB hex values are clamped conversions of
  the POC OKLCH; eyeball on Chrome (light + dark) and adjust if a tint
  reads wrong — they are centralized tokens, so a fix is one-line.

## Verification
Web/Chrome only locally (no Android SDK here; persistence = localStorage),
plus headless `flutter test` for the unit/widget logic.

Math mode:
- [ ] Third pill "Math"/"Počítání" appears after Symbols and switches to the
      board (EN + CS).
- [ ] Grid is 4 equal columns: digits + `.` neutral; `÷ × − +` teal column;
      `< > =` violet row; `⌫` neutral bottom-right; `0` spans two cells;
      `=` is a normal peer (not enlarged/highlighted).
- [ ] Glyphs are true `× ÷ − = < >`, not `x / -` (inspect rendered text).
- [ ] `4`,`2` → single tile `42`; `3 + 4 = 7` → five tiles `3 + 4 = 7`.
- [ ] `⌫` trims a digit off a number, then drops a whole sign.
- [ ] Math tiles tap-to-✕ remove; the trailing in-progress token shows the
      caret (no ✕) while typing.
- [ ] Speak in math: `12 × 5 =` → "twelve times five equals" /
      "dvanáct krát pět rovná se"; mood voice/rate/pitch ride on top.
- [ ] Switch Math→Keyboard→Math: problem preserved; sentence separate.

Inline numbers:
- [ ] English: permanent digit row present, NO `123` key.
- [ ] Czech: `123` key in the bottom (space) row; tap swaps the diacritics
      row to `0–9` in place (no motion/overlay); label flips `123`⇄`ABC`;
      stays until pressed again.
- [ ] Inline digit in a CS sentence speaks naturally ("two", not an operator
      word); consecutive digits group into one tile.

Workspaces:
- [ ] Keyboard→Math: sentence set aside (restored on return); math empty or
      last problem.
- [ ] Math→Keyboard: sentence intact; math remembered until cleared.
- [ ] Keyboard⇄Symbols share one buffer.
- [ ] Language switch clears only the sentence; a math problem survives.

Parity & quality:
- [ ] All of the above identical in EN and CS (incl. the full Czech
      diacritics row when not swapped).
- [ ] `flutter analyze` clean; unit tests + headless widget suite green;
      integration suite green on Chrome.
- [ ] AAC pass: op/rel glyph contrast ≥ 3:1 (large bold text) on light and
      dark; `⌫` icon contrast passes; shapes are abstract (no faces);
      every math key rect ≥ 72×72 at tablet size.
- [ ] **After visual sign-off only**: `test/math_board_golden_test.dart`
      passes against committed light + dark baselines; red on intentional
      reskins and recovers via `flutter test --update-goldens`.

## Deferred (do NOT implement now — matches the addendum)
- **Advanced Math mode** — the future home for `≠ ≤ ≥` and richer operators.
- **Speak-while-typing (per-key echo)** — if revived, re-speak the whole
  running number on each digit (modeling place value), operators as their
  word; parent-optional, default OFF.
- **Cross-linking the Symbols "Numbers" pictogram category** to the math
  board.

## Critical files
- `lib/core/theme.dart`
- `lib/core/math_speak.dart` (new)
- `lib/state/composer_controller.dart`
- `lib/state/language_controller.dart`
- `lib/widgets/math_board.dart` (new)
- `lib/widgets/home_page.dart`
- `lib/widgets/top_bar.dart`
- `lib/widgets/keyboard_view.dart`
- `lib/widgets/speak_button.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_cs.arb` (+ generated `app_localizations*.dart`)
- `test/math_speak_test.dart` (new)
- `test/composer_controller_math_test.dart` (new) — or extend an existing controller test
- `integration_test/addendum02_suite.dart`, `integration_test/addendum02_test.dart` (new)
- `test/addendum02_test.dart` (new, headless entry)
- `test/math_board_golden_test.dart` (new, **gated on visual sign-off**) + `goldens/math_board_light.png`, `goldens/math_board_dark.png`
