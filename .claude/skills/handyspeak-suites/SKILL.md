---
name: handyspeak-suites
description: Physically write a HandySpeak test suite — a plain headless test/<feature>_test.dart on the shared test/support/app_harness.dart, plus the one device_smoke pair under integration_test/. Use when adding or extending a feature's tests, or when a storage-key rename or test-key change must ripple through existing suites.
---

# HandySpeak test suites

`docs/testing-strategy.md` is the source of truth for **what** we test, **where**,
and the tier vocabulary — **Unit**, **Behavior**, **Device smoke**. Read it first
if you are deciding coverage. This skill governs the other half: **how to
physically write a suite** once you know what it must cover.

Canonical harness to import and copy shapes from: `test/support/app_harness.dart`
(`pumpApp`, `FakeTts`, `readProvider<T>`).

## Where a feature's tests live

A feature's Unit + Behavior tests are a **plain headless file**
`test/<feature>_test.dart` — a normal `void main()` with `test` / `testWidgets`
that imports the shared harness:

```dart
import 'support/app_harness.dart';
```

No suite body, no binding init, no `integration_test/` twin. It runs on the Dart
VM in seconds via `puro flutter test test/<feature>_test.dart`.

**Name by feature, never by addendum number.** ADDENDUM numbers are planning
artifacts, not units of behaviour; a suite named after one accretes unrelated
assertions and no one can find a feature's tests. The nine canonical feature
slugs are the complete set:

`message_composition` · `keyboard_input` · `symbols_pictograms` · `math_board` ·
`saved_phrases` · `language_set` · `speech_tts` · `settings` · `forgiving_tap`

New tests slot into the existing feature file; a genuinely new feature gets a new
slug in the same shape.

## The device smoke — the ONE surviving `integration_test/` consumer

The device smoke is the only thing left under `integration_test/`, and it is a
**pair, not a trio**:

| File | Role |
|---|---|
| `integration_test/device_smoke_suite.dart` | `runDeviceSmokeSuite()` — the body; walks one end-to-end path. **No binding init.** |
| `integration_test/device_smoke_test.dart` | On-device entry: `IntegrationTestWidgetsFlutterBinding.ensureInitialized(); runDeviceSmokeSuite();` |

**There is no headless `test/` entry for it — deliberately.** The smoke's whole
reason to exist is the on-device path (a genuine TTS-adjacent call) that the
headless tiers structurally cannot prove. A headless twin would either duplicate
feature coverage the Behavior tier already owns, or — if it exercised the real
device call — it can't run green off-device and would break the green gate. So
the smoke stays device-only.

It is a per-release sanity check, not per-feature coverage. Runs manually,
Android-only today:
`puro flutter test integration_test/device_smoke_test.dart -d <device>`.

## Harness mechanics

Import these from `test/support/app_harness.dart`; do not re-implement them per
file.

- **`pumpApp(tester, prefs: {...})`** — 1280×800 landscape viewport, DPR 1.0,
  reset via `addTearDown(tester.view.reset)`;
  `SharedPreferences.setMockInitialValues(prefs)` before `StorageService().init()`;
  a `FakeTts` installed **before** `SpeechService().init()`; the real controllers
  (`SettingsController`, `PhrasesController`, `ComposerController`,
  `LanguageController`) constructed and `load()`ed exactly like `lib/main.dart`
  does; `pumpWidget(HandySpeakApp(...))` then `pumpAndSettle()`. Returns a handle
  exposing storage + tts for assertions.
- **`FakeTts`** — mocks the `flutter_tts` `MethodChannel` at the platform-channel
  level; records every call; `isLanguageAvailable` → true, `getVoices` → a
  **mutable** voices list (defaults to en-US + cs-CZ only, so "missing uk voice"
  scenarios are the natural start), everything else → 1. Add a `spokenTexts`
  getter when tests assert what was spoken.
- **`readProvider<T>(tester)`** —
  `Provider.of<T>(tester.element(find.byType(HomePage)), listen: false)`.
- Small act helpers (e.g. `openSettings(tester)` taps the gear icon and settles).

## Seeding rules

- **Seed real storage keys.** Controllers restore from `shared_preferences` and
  decide fresh-install vs. restore by key *presence*. A seed that omits a key can
  silently take the fresh-install path and erase sibling keys (e.g. seeding
  `second_lang` without `main_lang` post-ADDENDUM-04). Mirror the exact keys the
  controllers write — check the `_k*` constants in `lib/state/` — never hand-roll
  controller state.
- **After any storage-key rename, grep both `test/` and `integration_test/` for
  the old key.** Stale seeds fail as confusing defaults, not errors — a
  green-looking rerun can be testing the fresh-install path instead of the case
  you meant.

## Finders and locale rules

- Tap by `ValueKey` test keys (the `settingsLangPicker_*` convention), never by
  localized text — copy edits and locale flips break text finders.
- Chrome (Settings labels, buttons, hints) follows the **main** language; board
  surfaces (keyboard layout, pictograms, phrases) follow the **active** language
  (ADR-0002). Assert against the right one, and construct expected strings from
  the generated locale classes (`AppLocalizationsEn()`, `AppLocalizationsUk()`, …)
  rather than literals.

## Done when

- [ ] The feature's tests live in `test/<feature>_test.dart` (feature slug, not an
      addendum number), importing `support/app_harness.dart`; no
      `integration_test/` twin for it.
- [ ] If the device smoke was touched, its **pair** is intact —
      `integration_test/device_smoke_suite.dart` (body, no binding init) +
      `integration_test/device_smoke_test.dart` (binding init +
      `runDeviceSmokeSuite()`); still no headless `test/` entry.
- [ ] `puro flutter analyze` is clean.
- [ ] `puro flutter test test/<feature>_test.dart` is green (fast loop).
- [ ] Full `puro flutter test` is green — including the *other* feature files,
      since storage-key and test-key changes ripple into them.
- [ ] The on-device smoke run is offered to the user (agent can't verify it):
      `puro flutter test integration_test/device_smoke_test.dart -d <device>`.
