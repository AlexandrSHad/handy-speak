# HandySpeak — POC Implementation Plan

> **For the coding agent:** Read this file top to bottom before writing any code.
> Build the tasks in order. Each task has acceptance criteria — do not move on
> until the current task meets them. This is a **proof of concept**, not a
> production app: prioritize a working end-to-end feel over robustness,
> test coverage, or edge-case handling. When something is ambiguous, prefer the
> simplest implementation that satisfies the acceptance criteria, and leave a
> `// TODO(poc):` note rather than over-building.

---

## 1. What we are building

HandySpeak is a cross-platform AAC (Augmentative and Alternative Communication)
tablet app for children with physical or speech disabilities. The child composes
a message — by typing on an on-screen keyboard or by tapping picture symbols —
and taps **Speak** to play it back as synthesized speech, so they can communicate
with peers independently.

This POC exists to feel out whether the idea works. Target form factor is a
**landscape tablet**.

## 2. Locked decisions

- **Framework:** Flutter, single codebase.
- **Target for this POC:** **Android only** (emulated tablet or physical Android
  tablet). iOS is supported by the codebase but **will be built later on a Mac** —
  do not attempt to build or run iOS, and ignore the Xcode line in `flutter doctor`.
- **Speech (core feature):** `flutter_tts` with the engine's **default**
  rate / pitch / volume. Online speech is fine.
- **Moods:** **off and disabled for the POC.** No `MoodStrip` is rendered, the
  message bar shows no mood voice-chip, and speech always uses default rate/pitch
  (i.e. the prototype's *"Mood voices off · steady voice"* state — use that artboard
  as the visual reference). Settings still shows the **"Mood voices"** row but it is
  **off by default and rendered disabled/greyed** (cannot be toggled on). Design
  `SpeechService.speak()` to accept **optional** `rate`/`pitch` params (unused now)
  so moods can be re-enabled later as a wiring change, not a refactor.
- **Languages:** **Czech (`cs-CZ`) and English (`en-US`) from the start.**
  A single global language selector flips **everything at once**: UI chrome
  strings, keyboard layout, symbol word set, My Phrases set, and the TTS language.
- **Keyboard:** English = QWERTY. Czech = **QWERTZ with diacritics**
  (á č ď é ě í ň ó ř š ť ú ů ý ž). The layout swaps with the active language.
- **Symbols:** **per-language** word sets (emoji is shared; label + spoken word
  differ by language).
- **My Phrases:** **per-language** (a Czech set and an English set).
- **Editable message:** word tiles with **tap-to-remove (✕) only** for the POC.
  Move / swipe-to-remove / hold-to-reorder are deferred.
- **Local storage:** `shared_preferences` (JSON-encoded).
- **State management:** `provider`.
- **Localization:** `flutter_localizations` + `intl` with ARB files
  (`generate: true` + `l10n.yaml`).

## 3. Explicitly out of scope (do NOT build)

Mood-driven pitch & rate (the toggle exists but stays off+disabled — see §2) ·
Snap & Say (camera) · word prediction · offline TTS models · switch scanning ·
multi-device voice consistency · iOS build · authentication · backend / cloud
sync · analytics · tests.

> Cutting Snap & Say, prediction, and scanning also removes their UI: the top-bar
> **Snap pill**, the symbol board's **snap tile + "Just snapped" recent strip**, and
> the keyboard's **prediction row** are all gone. Do not port them.

## 4. Tech stack & dependencies

Add to `pubspec.yaml` (`flutter pub get` after):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_tts: ^4.0.0          # use latest stable
  provider: ^6.1.0             # use latest stable
  shared_preferences: ^2.2.0   # use latest stable
  intl: any                    # version pinned by flutter_localizations

flutter:
  generate: true               # enables ARB code generation
  uses-material-design: true
```

Create `l10n.yaml` at the repo root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

Platform notes:
- `flutter_tts` requires Android `minSdkVersion 21`. Current Flutter defaults
  satisfy this; only edit `android/app/build.gradle` if a build complains.
- The **Czech voice pack must be present on the test device.** On Android this
  may require a one-time install under system *Text-to-speech* settings.

## 5. Suggested project structure

```
lib/
  main.dart                      # app entry, providers, MaterialApp + localizations
  l10n/
    app_en.arb
    app_cs.arb
  core/
    app_language.dart            # enum { en, cs } + locale + ttsLocale helpers
    theme.dart                   # ALL colors/spacing/radii/typography tokens here
  services/
    speech_service.dart          # flutter_tts wrapper (init, setLanguage, speak, stop, state)
    storage_service.dart         # shared_preferences read/write (JSON)
  state/
    language_controller.dart     # ChangeNotifier: active language, flips everything
    composer_controller.dart     # ChangeNotifier: message text, word tiles, mode
    phrases_controller.dart      # ChangeNotifier: per-language phrases, persisted
  data/
    categories.dart              # symbol categories (per-language labels)
    pictograms.dart              # { emoji, en, cs } records, grouped by category
    keyboard_layouts.dart        # QWERTY (en) + QWERTZ-with-diacritics (cs)
  widgets/
    top_bar.dart                 # brand, Keyboard/Symbols toggle, language toggle, settings
    message_bar.dart             # editable word tiles + word count + Clear
    speak_button.dart            # default-voice Speak, "Speaking…" state
    keyboard_view.dart
    symbol_board.dart
    phrase_strip.dart
    settings_sheet.dart
```

Keep **all** visual styling in `core/theme.dart` as tokens. The real HandySpeak
design will be supplied later; centralizing the theme makes reskinning a
find-and-replace rather than a rewrite. Keep **content** (categories, pictograms,
phrases, layouts) in `data/`, separate from widgets.

## 6. Bilingual data model

```dart
// A picture symbol: emoji is language-neutral; label + spoken word vary.
class Pictogram {
  final String emoji;   // '🍎'
  final String en;      // 'apple'
  final String cs;      // 'jablko'
  const Pictogram(this.emoji, this.en, this.cs);
  String word(AppLanguage l) => l == AppLanguage.cs ? cs : en;
}

// A quick phrase belongs to one language.
class Phrase {
  final String text;
  final bool pinned;
  final int uses;
  // stored under a per-language key, e.g. "phrases_en" / "phrases_cs"
}
```

The active `AppLanguage` resolves to:
- a Flutter `Locale` for UI strings (`en` / `cs`),
- a TTS locale string (`en-US` / `cs-CZ`),
- which keyboard layout to render,
- which pictogram word/label and which phrase set to show.

## 6.1 Confirmed UX behaviors (resolved during prototype review)

These were ambiguous in the prototype-vs-plan comparison and are now **locked**:

1. **Clear the message on language switch.** Switching EN⇄CS (top bar toggle *or*
   settings) **clears the composed message**, cancels any in-progress speech, then
   flips the board + TTS language. Rationale: free-typed text can't be auto-translated
   and already-added symbol words are literal strings, so switching would otherwise
   produce a mixed-language sentence. (Matches the prototype's `changeLang`.)
2. **In-progress word is not a removable tile** (keyboard mode). While the child is
   typing and the last word is **not** yet space-terminated, render it as the *active*
   word with a caret — **not** as a tap-to-remove ✕ tile. A word becomes an editable
   tile only once a space (or another word) follows it. Replicate the prototype's
   `activeIndex` handling in `MessageBlocks`. Symbol/phrase taps always produce
   complete, immediately-editable tiles.
3. **Responsive layout — do not hard-code the prototype's pixels.** The prototype is
   authored at a fixed **1280×920** (≈4:3) with absolute sizes (88px keys, 130px
   symbol cards). Real Android tablets are commonly **16:10 / 16:9** (vertically
   tighter). Build with `Expanded`/`Flexible`/`LayoutBuilder` and a flexible grid so
   the keyboard + message bar + phrase strip + symbol grid all fit without overflow on
   a 16:9 panel in landscape. Keep the design tokens (tap-target minimums, radii,
   spacing scale) but let the layout flex. Note the Czech diacritics row has **15
   keys** vs 10 in a QWERTY row — size keys to the row, not to a fixed width.
4. **My Phrases — genuinely per-language & persisted** (this differs from the
   prototype). The prototype kept one shared in-memory list translated via a lookup;
   **we do not.** Build two independent lists (`phrases_en`, `phrases_cs`), each
   seeded, each editable on its own, each persisted via `shared_preferences`. A parent
   may add a Czech phrase with no English counterpart.

## 6.2 Free content to port from the prototype bundle

This content is ready to lift verbatim — don't re-author it (source files are in the
`HandySpeak-handoff` bundle):

- **Vocabulary** (8 categories × ~10 pictograms, emoji + EN + CS) — from
  `WORDS_CS` / `PICTOGRAMS` → the §6 `Pictogram(emoji, en, cs)` records.
- **UI strings** (`UI.en` / `UI.cs` maps in `i18n.jsx`) → `app_en.arb` / `app_cs.arb`.
  *Skip* strings for cut features (snap, prediction, scanning, mood copy).
- **Czech word-count pluralization** (1 slovo · 2–4 slova · 5+ slov) → use ARB's
  native **plural** syntax, not a hand-rolled `if`.
- **Keyboard layouts** (`LAYOUTS` map) → `keyboard_layouts.dart`.
- **Design tokens** (Fredoka display + Nunito body, 4/8/12/16/24/32/48 spacing,
  radii, **72px min tap target**, surface/ink palette) → `core/theme.dart`.
- **Visual reference for the moods-off layout:** the prototype's *"Mood voices off"*
  artboard (`initialMoodEnabled={false}`).

## 7. Build order (tasks)

> Verify each task on an **Android emulator or device** before continuing.

### Task 0 — Confirm toolchain & scaffold
- [ ] `flutter doctor` is green for Android (Xcode line may stay red — expected).
- [ ] Project scaffolds and runs the default counter app on an Android target.
- [ ] Add the dependencies from §4; `flutter pub get` succeeds.
- **Done when:** the app launches on the Android target with the new deps resolved.

### Task 1 — SpeechService + Czech/English speak-test (de-risk first)
This is the highest-risk piece, so prove it before building UI.
- [ ] Implement `SpeechService` wrapping `flutter_tts`: `init()`, `setLanguage(String locale)`,
      `speak(String text)`, `stop()`, and an `isSpeaking` flag driven by the
      completion/error handlers.
- [ ] On init, check `isLanguageAvailable('cs-CZ')` and `isLanguageAvailable('en-US')`
      and log/expose the result. **Treat this as a soft signal only** — on Android it
      can return `true` while the voice **data pack isn't installed** (it reports
      "engine supports the language", not "audio will play"). Use it to drive the
      in-app *"No Czech voice…"* warning, but rely on the audible check below as the
      real proof. Do **not** attempt to programmatically detect silent synthesis.
- [ ] `speak()` accepts **optional** `rate`/`pitch` (default = engine default) so moods
      can be re-enabled later without changing the call sites. POC always passes the
      defaults.
- [ ] Throwaway screen with two buttons: **Speak English** ("Hello, I want to play")
      and **Speak Czech** ("Ahoj, chci si hrát").
- **Done when:** both buttons produce audible, correct-language speech on the
  Android target. If Czech is silent, the device is missing the Czech voice pack —
  surface that clearly rather than failing quietly. (One-time fix: install the Czech
  voice under the device's system *Text-to-speech* settings — see §4.)

### Task 2 — Localization scaffolding + language controller
- [ ] Create `app_en.arb` and `app_cs.arb` with the UI strings used so far
      (app title, mode labels, Speak, Clear, Settings, etc.). Add strings as later
      tasks need them.
- [ ] `MaterialApp` wired with `localizationsDelegates` + `supportedLocales`
      (`en`, `cs`).
- [ ] `LanguageController` (ChangeNotifier) holding the active `AppLanguage`;
      changing it updates the app `Locale`, calls `SpeechService.setLanguage`,
      cancels in-progress speech, and **clears the composed message** (§6.1.1).
      (Wire the clear once `ComposerController` exists in Task 3.)
- **Done when:** flipping the language in code switches both visible UI strings
  and the spoken language, and clears any composed message.

### Task 3 — App shell
- [ ] `TopBar`: brand, a Keyboard/Symbols segmented toggle, a language toggle
      (EN/CS), and a settings button.
- [ ] `MessageBar` placeholder + `SpeakButton` below the top bar.
- [ ] `ComposerController` holding the message text and current input mode.
- **Done when:** the shell renders in landscape; the mode toggle and language
  toggle are wired to state.

### Task 4 — Message bar with editable word tiles + Speak
- [ ] Render the message as **word tiles**. Tapping a tile reveals a ✕ that removes
      that word. (Tap-to-remove only.)
- [ ] **In-progress word handling (§6.1.2):** the last word, while still being typed
      (no trailing space), renders as the *active* word with a caret — **not** a
      removable ✕ tile. It becomes an editable tile only once a space follows.
- [ ] Word count (Czech plural-aware, §6.2) and a **Clear** action.
- [ ] No mood voice-chip is shown (moods off, §2).
- [ ] **Speak** plays the full message with the default voice in the active language;
      button shows a "Speaking…" state while `isSpeaking` is true; disabled when empty.
- **Done when:** the child can compose text (via any source), remove a word by
  tapping its ✕, clear, and hear the message spoken in the active language.

### Task 5 — Keyboard mode
- [ ] `keyboard_layouts.dart`: English QWERTY and Czech **QWERTZ with the diacritics
      set**. Include shift, backspace, and space.
- [ ] `KeyboardView` renders the layout for the active language and appends/edits
      the composer text. Layout swaps when the language changes.
- [ ] **Responsive (§6.1.3):** size keys to fill the row, not to fixed px. The Czech
      diacritics row has **15 keys** vs 10 in a QWERTY row — both rows must fit the
      same width without overflow. No prediction row (cut, §3).
- [ ] Diacritic keys insert the accented char directly (no dead-key/combining logic).
- **Done when:** typing in English uses QWERTY and typing in Czech uses QWERTZ with
  working diacritics; both feed the message bar; no overflow on a 16:9 landscape panel.

### Task 6 — Symbols mode
- [ ] `categories.dart` + `pictograms.dart` with per-language words. A few categories
      (e.g. Feelings, Food, School, Activities) with ~8–10 symbols each is plenty
      for the POC.
- [ ] `SymbolBoard`: category rail + pictogram grid; tapping a symbol appends its
      active-language word to the message.
- **Done when:** tapping symbols composes a message whose words and spoken output
  match the active language.

### Task 7 — My Phrases (per-language, persisted)
- [ ] `PhrasesController` holds a **per-language** list of phrases (seed each
      language with a handful of starters). Tapping a phrase loads it into the
      message bar.
- [ ] `PhraseStrip` shows pinned-first, then by use count.
- [ ] Persist via `StorageService` (`shared_preferences`, JSON, keyed per language).
- **Done when:** phrases differ by language, survive an app restart, and tapping
  one composes it.

### Task 8 — Settings sheet
- [ ] Language selector (EN/CS), dark mode toggle, and parent management of phrases
      (add / remove / pin) for the active language.
- [ ] **Mood voices** row present but **off + disabled/greyed** (cannot toggle on, §2).
- [ ] Optional: haptic feedback toggle (use Flutter `HapticFeedback`).
- [ ] Czech voice-missing warning surfaces here when `cs` is active and the voice
      check fails (§4 / Task 1).
- **Done when:** settings changes take effect immediately and persist where relevant;
  the language selector also clears the message on switch (§6.1.1).

### Task 9 — Theming pass
- [ ] Ensure every widget pulls colors/spacing/radii/type from `core/theme.dart`.
- [ ] Apply a clean, child-friendly neutral theme + a dark variant.
- **Note:** the official HandySpeak design will be provided later; this task just
  makes the reskin easy. Do not invent a final visual identity.

## 8. Definition of done (POC)

A child can, on an Android tablet, in **either Czech or English**:
1. switch language and see the whole UI + keyboard + symbols + phrases switch
   (and the in-progress message clear, §6.1.1),
2. compose a message by typing **or** by tapping symbols,
3. fix the message by tapping a word's ✕,
4. tap **Speak** and hear it in the correct language with the default voice,
5. use saved per-language quick phrases that persist across restarts.

The whole UI must fit a **landscape 16:9 tablet** without overflow (§6.1.3).

## 9. Gotchas / agent reminders

- **Package name:** the Dart package must be `handy_speak` (lowercase + underscores).
  The containing folder may be `handy-speek`, but never use a hyphen in the package name.
- **No iOS build on this machine.** Skip it; the red Xcode line in `flutter doctor`
  is expected and fine.
- **Czech TTS** depends on the device voice pack. `isLanguageAvailable` is a soft
  signal (can be `true` with no audio when the data pack is absent — see Task 1);
  surface a clear message if Czech is missing — do not let it fail silently.
  Validate speech on the Android target, not desktop Chrome.
- **The prototype is a superset reference, not a spec.** It includes moods, Snap & Say,
  prediction, scanning, and 4 tile-edit affordances — all cut (§3). Port content (§6.2)
  and the moods-off layout, but build the *behaviors* from this plan (§6.1), not by
  copying the prototype.
- **Language switch clears the message** and cancels speech (§6.1.1). Don't carry
  composed text across a language change.
- **Don't hard-code the prototype's 1280×920 pixels** — lay out responsively (§6.1.3).
- **Speaking state:** use the `flutter_tts` completion/error handlers (and
  `awaitSpeakCompletion(true)` if helpful) to drive the button state reliably.
- Keep robustness minimal but **never let a TTS error crash the app** — catch and
  reset the speaking state.
- Commit in logical increments (one per task) with clear messages.
