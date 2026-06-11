# HandySpeak — Addendum 01: Big letters + Optional phrase strip

## Context

The handoff ADDENDUM-01 (`handoff/ADDENDUM-01 Big letters + Optional phrases.md`) specifies two approved parent settings validated in the web POC: **Big letters** (uppercase-only display mode for emergent readers — display-only transform, TTS/storage untouched) and **Show phrase shortcuts** (hide the text-only phrase strip for pre-readers; input area grows). The new `handoff/HandySpeak-handoff.zip` design was diffed against the old prototype — **it changes nothing beyond these two features** (plus a web-only switch flexbox bugfix).

Decisions agreed with the user:
- Spec surfaces absent from the Flutter POC (prediction bar, Snap & Say, undo chip) → **N/A, skip**; leave a code note for future surfaces.
- Symbol tiles must **actually grow** when the strip is hidden (rework grid sizing), not just show more scrollable rows.
- **Space key label stays lowercase** (letters only uppercase); digits/punctuation are no-ops.

Key codebase facts:
- Flutter has no CSS `text-transform` → uppercase happens via render-time `.toUpperCase()` at `Text` widgets only. Dart's Unicode casing handles Czech diacritics (á→Á, č→Č…) — no locale variant needed.
- `keyboard_view.dart:133` — `_CharKey` inserts its **label** (`onTap(label)`), so display and inserted value must be split.
- The web POC's switch-squash bugfix is N/A in Flutter: `_ToggleRow` (settings_sheet.dart:296) puts text in `Expanded` and `Switch` is a fixed-size non-flex child — **verify only**.
- `pubspec.yaml` has `generate: true` → l10n regenerates on build; `flutter gen-l10n` for immediate IDE resolution.

## Implementation steps

### 1. Settings state — `lib/state/settings_controller.dart`
Mirror the `_kHaptics` pattern: keys `'big_letters'` / `'show_phrases'`, fields + getters `bigLetters` (default **false**) and `showPhrases` (default **true**), load in `load()`, `setBigLetters()` / `setShowPhrases()` with persist + `notifyListeners()`. No `main.dart` change (`..load()` already called). Settings are language-independent → EN⇄CS keeps them.

### 2. Display transform — new `lib/core/text_display.dart`
```dart
/// Render-time-only casing for "Big letters" mode. Never mutate stored
/// text, phrases, or TTS input — apply at the Text widget only.
/// Apply to any future child-facing surface (prediction bar, Snap & Say,
/// undo chip) when those exist.
extension DisplayCase on String {
  String displayUpper(bool bigLetters) => bigLetters ? toUpperCase() : this;
}
```
One expression per call site, greppable for auditing surfaces.

### 3. l10n — `lib/l10n/app_en.arb` + `app_cs.arb`
Add 5 keys (exact addendum copy, app naming convention):
`settingsBigLettersName/Desc`, `settingsShowPhrasesName/Desc`, `settingsPhrasesHiddenNote` — EN + CS values from the spec table. Run `flutter gen-l10n`; commit regenerated `app_localizations*.dart`.

### 4. Settings UI — `lib/widgets/settings_sheet.dart`
- `_AccessibilitySection` (~line 247): Big letters `_ToggleRow` as **first** row (before haptics/dark).
- `_PhrasesSectionState.build` (~line 352): after `_SectionTitle`, add the Show-phrases `_ToggleRow` (needs `context.watch<SettingsController>()`); when OFF show `settingsPhrasesHiddenNote` as a small `ink3` note (lighter than `_VoiceWarning`); then `SizedBox(s8)` before the phrase list. Editor untouched/fully functional while hidden.
- Switch-squash: no code change; visual check with long CS descriptions.

### 5. Home page — `lib/widgets/home_page.dart`
```dart
final showPhrases = context.select<SettingsController, bool>((s) => s.showPhrases);
...
if (showPhrases) ...[
  const PhraseStrip(),
  const SizedBox(height: AppTokens.s12),
],
```
Strip + its 12pt gap removed together (no blank band). Keyboard rows are all `Expanded` → stretch automatically.

### 6. Keyboard — `lib/widgets/keyboard_view.dart`
- Watch `bigLetters` in build; `final effShift = _shift && !big;` (POC parity).
- **Split `_CharKey` into `label` (displayed) + `value` (inserted)**; `onTap(value)`:
  - `label: (big || (effShift && _hasCase(k))) ? k.toUpperCase() : k`
  - `value: effShift && _hasCase(k) ? k.toUpperCase() : k` → big-letters forces lowercase insertion.
  - 3 call sites, all in this file; `_SpaceRow` punctuation: `label: c, value: c`. Space key keeps lowercase `l10n.keySpace`.
- **Inert shift**: add `enabled` flag to `_ModKey`; when disabled → `Opacity(0.35)`, `InkWell(onTap: null)` (kills ripple/hover/tap), force `active: false`. Shift gets `enabled: !big, active: effShift`; backspace always enabled. `_shift` state left untouched while mode on (spec: treated OFF *while active*).

### 7. Message bar — `lib/widgets/message_blocks.dart` + `message_bar.dart`
`MessageBlocks` stays presentational: new `required bool bigLetters` param, passed from `message_bar.dart` (`context.watch<SettingsController>().bigLetters`). Apply `.displayUpper()` at exactly two `Text` sites: placeholder (~line 62) and word-tile text (~line 115). Tokens/removal/TTS stay on stored strings.

### 8. Phrase strip — `lib/widgets/phrase_strip.dart`
`.displayUpper(big)` on chip labels only; `loadText(p.text)` keeps stored phrase. "MY PHRASES" header is chrome — leave.

### 9. Symbol board — `lib/widgets/symbol_board.dart`
- `.displayUpper(big)` on pictogram label (~line 174) + category label (~line 120); `appendWord()` keeps stored casing.
- **Grid sizing rework** (replaces `childAspectRatio: 1`, ~lines 44–52): tiles fill available height exactly:
```dart
const spacing = AppTokens.s12;
final cols = (c.maxWidth / 150).floor().clamp(3, 8);          // unchanged
final tileW = (c.maxWidth - (cols - 1) * spacing) / cols;
final rowsVisible = ((c.maxHeight + spacing) / (tileW + spacing)).floor().clamp(2, 6);
final tileH = ((c.maxHeight - (rowsVisible - 1) * spacing) / rowsVisible)
    .clamp(tileW, tileW * 1.45);   // min square, max moderately tall
// SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: tileH, ...)
```
  `floor()` guarantees `tileH >= tileW` (never sub-square); hiding the strip stretches rows or admits one more full row — no partial-row jitter; dense categories still scroll.
- **Visible growth**: pass `tileH` into `_PictogramTile`; `emojiSize = (tileH * .30).clamp(40, 64)`, `labelSize = (tileH * .11).clamp(16, 22)` — resolves to ≈ current 40/16 with strip visible (no regression), grows when hidden.

## Commit sequence
1. Controller + extension + ARB + gen-l10n (additive, app unchanged) — steps 1–3
2. Settings sheet toggles + note — step 4
3. Strip removal + grid sizing — steps 5, 9(grid)
4. Big-letters rendering: keyboard split, message blocks, phrase strip, symbol labels — steps 6–8, 9(labels)

`flutter analyze` after each step.

## Risks
- **Highest risk**: accidentally passing `label` instead of `value` to `onTap` in `_CharKey` → stored text/TTS gets caps. Checklist covers it explicitly.
- Stale `_shift == true` under inert shift: turning Big letters OFF makes the next key uppercase once — matches POC/spec; note in PR.
- Uppercase tiles are wider → `Wrap` re-flow in message bar `AnimatedSize`; confirm no overflow at 2-row max.
- Grid clamps: eyeball several Chrome window sizes (web freely resizable).

## Verification (web/Chrome only — no Android SDK here; `flutter run -d chrome` via Puro toolchain, persistence = localStorage)

Big letters:
- [ ] ON: keyboard letters, word tiles, placeholder, pictogram labels, category names, phrase chips uppercase — EN and CS (full diacritic row Á Č Ď É Ě Í Ň Ó Ř Š Ť Ú Ů Ý Ž). Prediction/undo/Snap&Say: N/A
- [ ] Chrome stays normal: Speak, mode toggle, settings, word count, Clear, space key
- [ ] Shift visible, dimmed ~0.35, inert (no ripple/press); backspace works
- [ ] Shift on → enable Big letters → typing inserts lowercase (verify by toggling OFF)
- [ ] Speak with mode ON sounds identical to OFF
- [ ] Toggle OFF: instant revert, message intact
- [ ] EN⇄CS while ON keeps mode active

Phrases optional:
- [ ] OFF: strip + gap gone, keys taller, symbol tiles/emoji/labels visibly larger
- [ ] OFF: editor add/pin/unpin/remove works; hidden note shows in both languages
- [ ] ON: strip returns, phrases + pin order intact

Both:
- [ ] Toggles render full-size with long CS descriptions
- [ ] All 4 setting combinations work; both persist across reload
- [ ] `flutter analyze` clean

## Critical files
- `lib/state/settings_controller.dart`
- `lib/core/text_display.dart` (new)
- `lib/l10n/app_en.arb`, `lib/l10n/app_cs.arb`
- `lib/widgets/settings_sheet.dart`
- `lib/widgets/home_page.dart`
- `lib/widgets/keyboard_view.dart`
- `lib/widgets/message_blocks.dart`, `lib/widgets/message_bar.dart`
- `lib/widgets/phrase_strip.dart`
- `lib/widgets/symbol_board.dart`
