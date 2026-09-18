# Testing Strategy

_Status: adopted 2026-09-17. This document is the concept-level contract for how
HandySpeak is tested. It describes **what** we test and **at which layer** — not
how any individual test is written. The concrete prep steps this contract
depended on (the `SpeechService` injection seam, retiring the investigative red
tests, and standing up the by-feature suite skeleton) were completed in the
testing-prep stage._

## 1. Purpose & scope

HandySpeak is an AAC app: a non-verbal child taps letters, symbols, phrases, and
numbers to build a message and have it spoken aloud. A silent regression in that
path doesn't throw — it just makes the child say the wrong thing, or nothing.
That is the failure this strategy exists to catch.

The scope here is the **concept**: the tiers of testing we use, the features they
map onto, and the bar for "done". It deliberately contains no code, no test
method names, and no prescriptions about individual assertions. When a decision
turns out to have implementation shape, it belongs in a handoff or plan document
that points back here — not in this file.

## 2. Principles

1. **Test what the user touches.** Every behaviour a child (or the configuring
   parent) can trigger through the UI has a test that exercises it the way they
   would — building a message, loading a phrase, switching language, entering a
   sum, pressing speak.
2. **Cover the critical-path branches.** The defensive branches that keep the app
   from crashing or corrupting a message — empty-input guards, corruption
   fallbacks, fail-open voice checks, persistence round-trips — are tested
   explicitly, because they never fire in a happy-path demo.
3. **Fast by default, device only when it must be.** The overwhelming majority of
   coverage runs headless on the Dart VM in seconds, with no device or emulator.
   The device tier stays deliberately small.
4. **The green bar is the gate.** `puro flutter analyze` and `puro flutter test`
   must both pass. A red test is a broken build, never a documented "known
   failure" — see §6.

## 3. The three tiers

We name three tiers explicitly. The middle tier is the one people mislabel, so
the naming is load-bearing.

### Unit tests
Pure functions and controller logic with **no widget tree**. No binding, or only
the lightweight `TestWidgetsFlutterBinding` when a controller needs mocked
plugins. These are the fastest tests and cover translation/formatting logic,
enum resolution, controller state transitions, and static-data invariants.

_Lives in:_ `test/`. _Runs with:_ `puro flutter test`.

### Behavior tests
Flutter's **widget tests**, which — despite the confusing name — run **headless
on the Dart VM**, not on a device. They pump the real app (the same controllers
and widgets `lib/main.dart` wires up) and drive it through real gestures: tap a
key, tap a symbol, load a phrase, switch language. Plugins are stubbed at the
platform-channel level — `flutter_tts` via a fake method-call handler,
`shared_preferences` via `SharedPreferences.setMockInitialValues` — so no device
is involved. **This is the primary tier**: it is where "everything the user
interacts with" gets covered.

> Naming note: we call these **behavior tests**. They are Flutter's "widget
> tests". We reserve the phrase "integration tests" for the on-device tier below,
> because Flutter's own `integration_test/` folder already claims that meaning —
> calling the headless tier "integration tests" would collide with the framework.

_Lives in:_ `test/`. _Runs with:_ `puro flutter test`.

### Device smoke
A single thin on-device suite that boots the app on a real Android device and
walks one end-to-end path (including a genuine TTS-adjacent call the channel mock
can't prove out). It is a **per-release sanity check, not per-feature coverage** —
it exists to catch "the whole thing doesn't start on real hardware", which the
headless tiers structurally cannot see.

_Lives in:_ `integration_test/`. _Runs manually:_
`puro flutter test integration_test/<smoke>_test.dart -d <device>`. Android-only
today (see §7).

## 4. Feature map

Tests are organised **by feature**, one suite per feature. Each feature below
lists what its Unit and Behavior coverage means — as guidance, not a scored
checklist.

### Message composition
The shared sentence buffer and its word-tiles: appending characters and words,
backspace, clearing, removing a tile, the caret-vs-tile distinction, and
separator-space insertion.
- _Unit:_ `ComposerController` sentence-mode logic — append/word/backspace/remove
  ordering, `activeIndex` branching, space insertion, bounds checks, buffer
  routing between sentence and math.
- _Behavior:_ typing and editing a real message on the board and seeing the
  message bar reflect it, including word count.

### Keyboard input
The per-language key layouts and the act of tapping them into the buffer.
- _Unit:_ layout data-shape invariants (row counts, key sets, the Czech QWERTZ
  y/z swap, Cyrillic set).
- _Behavior:_ tapping letter/number/accent keys inserts the right glyph; big-letter
  rendering affects display only, never stored/spoken text.

### Symbols & pictograms
Category → pictogram selection and the word each pictogram contributes.
- _Unit:_ every category has pictograms; every pictogram has non-empty EN/CS/UK
  words; category↔pictogram cross-reference is complete.
- _Behavior:_ tapping a symbol appends its language-resolved word to the message.

### Math board
The separate math buffer and its spoken translation.
- _Unit:_ `mathSpeak` / digit / operator / delete logic, including the true minus
  (U+2212) and per-language glyph→word translation with EN fallback.
- _Behavior:_ entering a sum on the math board, and speak producing spoken words
  rather than raw glyphs; the math buffer surviving a language switch.

### Saved phrases
The per-language phrase store: seeding, ordering, mutation, persistence.
- _Unit:_ `PhrasesController` — pinned-first/uses-descending sort, seed vs restore,
  JSON round-trip, corruption falls back to seed, empty add rejected, remove/toggle
  matching.
- _Behavior:_ loading a phrase into the message; the phrase strip showing/hiding
  per the Settings toggle.

### Language set & localization
The main/second language pair, first-run seeding, the active language, and the
ADR-0002 UI-locale pin.
- _Unit:_ `LanguageController` — first-run device seeding matrix, unsupported-device
  handling, active snap-back when the stored active isn't in the set, main/second
  swap symmetry, single-notify discipline, persistence (absence encodes "no second
  language").
- _Behavior:_ switching the active language re-points the board and TTS while the
  UI chrome stays pinned to the main language; the second-language switch and
  pickers.

### Speech / TTS
The speech service's defensive contract around `flutter_tts`.
- _Unit:_ `SpeechService` — init timeout → `unavailable`, never completes with an
  error, `speak` early-returns on empty/not-ready, error-swallowing, status
  transitions, fail-open `hasVoiceFor`. (Enabled by the `TtsEngine` injection
  seam.)
- _Behavior:_ the speak button's enabled/disabled gating on status and text; the
  math-vs-sentence source selection feeding the spoken string.

### Settings
The persisted preference flags and the settings dialog.
- _Unit:_ `SettingsController` load defaults/fallbacks and persist-on-set for each
  flag.
- _Behavior:_ the settings dialog (ADR-0003) — category rail, pane state, instant
  apply, dismissal, pinned add row.

### Forgiving-tap / accessibility
The release-within-bounds tap contract for children whose fingers drift.
- _Behavior:_ `ForgivingTap` activates on release inside bounds, tolerates slide,
  and is fully inert when `onTap` is null — the passing key-tap behaviours migrate
  here.

## 5. Migration: from addendum suites to feature suites

### Why by feature, not by addendum

Suites named after ADDENDUM planning numbers are the wrong axis. An ADDENDUM
number is a **planning artifact, not a unit of behaviour** — a suite named after
one grows to assert unrelated things, and no one can find the tests for a given
feature. `addendum03`, for example, mixes Ukrainian localization, the language
pair, and per-language voice-pack warnings — three different features in one
file. Organising by feature means each suite has one subject, and the tests for a
behaviour live where you'd look for them.

### The mapping

The existing addendum suites are **cross-cutting**: each touches several features.
Migration means splitting each suite's groups out to the feature suite they
belong under, reusing the existing assertions where they still hold. The addendum
naming then disappears.

| Existing suite | Groups redistribute to |
| --- | --- |
| `addendum01` | Keyboard input (big letters) · Saved phrases (phrase strip) · Settings (toggles) |
| `addendum02` | Math board · Message composition (dual workspaces) · Language (Czech inline numbers) |
| `addendum03` | Language set & localization (Ukrainian, language pair) · Speech/TTS (voice-pack warnings) |
| `addendum04` | Language set & localization (seeding, second-language switch, ADR-0002 pin) |
| `addendum05` | Settings (settings dialog) |
| `keytap` | Forgiving-tap / accessibility (passing tests only) |

The two deliberately-red `keytap` "THE BUG" tests were investigation scaffolding,
not coverage; they are retired, not migrated (see §6).

## 6. Definition of done

- Every user-facing behaviour and every critical-path branch listed in §4 has a
  test at the appropriate tier.
- `puro flutter analyze` passes.
- `puro flutter test` passes **green** — no expected-failure or skipped tests
  standing in for unfinished work. If a behaviour is known-broken, its test is
  removed along with the investigation, or the behaviour is fixed; the suite never
  carries a documented red.

There is no numeric coverage target and no scored per-feature checklist. The bar
is behavioural completeness against §4 plus the green gate — a percentage invites
gaming, and the feature map already says what "enough" means.

## 7. iOS note

The device-smoke tier is **Android-only today**; iOS is a stated target, deferred
pending Mac access. When iOS comes online, the smoke suite will need its own pass
for iOS-specific concerns — safe areas around the board and message bar, and touch
semantics for `ForgivingTap` — so they aren't a fresh discovery. The Unit and
Behavior tiers are platform-agnostic and already exercise the logic that iOS will
share.
