---
name: handyspeak-suites
description: Create or update HandySpeak's paired test suites — one shared run<Suite>() body consumed by both a headless test/ entry and an on-device integration_test/ entry. Use when adding tests for a feature (addendum or standalone), creating or extending a suite pair, or when a storage-key rename or test-key change must ripple through existing suites.
---

# HandySpeak test suites

Canonical example to copy from: `integration_test/addendum03_suite.dart`
(newest, richest harness). Older pairs: `addendum01`, `addendum02`, `keytap`.

## The pairing rule

Every feature's tests land as a **suite trio** sharing one body:

| File | Role |
|---|---|
| `integration_test/<name>_suite.dart` | `run<Name>Suite()` — all groups, tests, and the shared harness. Contains **no binding init**; each entry point does its own. |
| `integration_test/<name>_test.dart` | On-device entry: `IntegrationTestWidgetsFlutterBinding.ensureInitialized(); run<Name>Suite();` |
| `test/<name>_test.dart` | Headless entry: `import '../integration_test/<name>_suite.dart';` then `run<Name>Suite();` |

The headless entry is the agent's fast loop (`puro flutter test test/<name>_test.dart`,
seconds, Dart VM); the on-device entry runs the identical body against a real
Android device (`puro flutter test integration_test/<name>_test.dart -d <device>`,
manual — web and desktop are unsupported here). One body, two worlds: never
fork logic between them.

## Harness checklist

Build the suite around these pieces (copy shapes from `addendum03_suite.dart`):

- **`pumpApp(tester, prefs: {...})`** — 1280×800 landscape viewport, DPR 1.0,
  reset via `addTearDown(tester.view.reset)`; `SharedPreferences.setMockInitialValues(prefs)`
  before `StorageService().init()`; a `FakeTts` installed **before**
  `SpeechService().init()`; the real controllers (`SettingsController`,
  `PhrasesController`, `ComposerController`, `LanguageController`) constructed
  and `load()`ed exactly like `lib/main.dart` does; `pumpWidget(HandySpeakApp(...))`
  then `pumpAndSettle()`. Returns a handle (`TestApp`) exposing storage + tts
  for assertions.
- **`FakeTts`** — mocks the `flutter_tts` `MethodChannel`; records every call;
  `isLanguageAvailable` → true, `getVoices` → a **mutable** voices list
  (defaults to en-US + cs-CZ only, so "missing uk voice" scenarios are the
  natural start), everything else → 1. Add a `spokenTexts` getter when tests
  assert what was spoken.
- **`readProvider<T>(tester)`** — `Provider.of<T>(tester.element(find.byType(HomePage)), listen: false)`.
- Small act helpers (e.g. `openSettings(tester)` taps the gear icon and settles).

## Seeding rules

- **Seed real storage keys.** Controllers restore from `shared_preferences`
  and decide fresh-install vs. restore by key *presence*. A seed that omits a
  key can silently take the fresh-install path and erase sibling keys
  (e.g. seeding `second_lang` without `main_lang` post-ADDENDUM-04). Mirror
  the exact keys the controllers write — check the `_k*` constants in
  `lib/state/` — never hand-roll controller state.
- **After any storage-key rename, grep both dirs for the old key.** Stale
  seeds fail as confusing defaults, not errors — a green-looking rerun can be
  testing the fresh-install path instead of the case you meant.

## Finders and locale rules

- Tap by `ValueKey` test keys (the `settingsLangPicker_*` convention), never
  by localized text — copy edits and locale flips break text finders.
- Chrome (Settings labels, buttons, hints) follows the **main** language;
  board surfaces (keyboard layout, pictograms, phrases) follow the **active**
  language (ADR-0002). Assert against the right one, and construct the
  expected strings from the generated locale classes
  (`AppLocalizationsEn()`, `AppLocalizationsUk()`, …) rather than literals.

## Done when

- [ ] All three files exist (or the touched pair is updated); entries contain
      only binding init + the `run<Name>Suite()` call.
- [ ] `puro flutter analyze` is clean.
- [ ] `puro flutter test test/<name>_test.dart` is green (fast loop).
- [ ] Full `puro flutter test` is green — including the *other* suites, since
      storage-key and test-key changes ripple into them.
- [ ] The on-device run is offered to the user (agent can't verify it):
      `puro flutter test integration_test/<name>_test.dart -d <device>`.
