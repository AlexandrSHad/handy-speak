# HandySpeak

## Project description

This is a project the sole goal of which is to build a cross-platform AAC
(Augmentative and Alternative Communication) tablet app for children with
physical or speech disabilities. Primary target: tablet (iOS & Android).

Core purpose: Let non-verbal or speech-impaired kids type messages and play
them back as synthesized speech, so they can communicate with peers
independently.

The app is **bilingual: English + Czech** (English is the localization
template; Czech is the secondary locale).

## Technology stack

- **Flutter** (Dart SDK `>=3.4.0 <4.0.0`), Material Design. App name/package:
  `handy_speak`, version in `pubspec.yaml`.
- **State management:** `provider` + `ChangeNotifier`. Controllers live in
  `lib/state/` and are injected via `MultiProvider` in `lib/main.dart`.
- **Text-to-speech:** `flutter_tts` (`lib/services/speech_service.dart`).
- **Local persistence:** `shared_preferences`, wrapped by
  `lib/services/storage_service.dart`.
- **Localization:** `flutter_localizations` + `intl`, ARB-driven
  (`lib/l10n/`, configured by `l10n.yaml`).
- **Android:** JVM 17, namespace `com.handyspeak.handy_speak`, Flutter-default
  min/target SDK; launcher-icon `minSdk` 21.
- **Linting:** `flutter_lints` (`analysis_options.yaml`).
- **Build/codegen tooling:** `flutter_launcher_icons`,
  `flutter_native_splash` (brand color `#1fa567`).

## Platforms

Tablet, **landscape-first** (orientation locked in `lib/main.dart`).
**Android is primary today; iOS is a stated target, currently deferred
pending Mac access.** Every design and plan should note iOS-specific concerns
(safe areas, touch semantics) even while building Android-only, so they
aren't a fresh discovery later.

## Project layout

```
lib/
  core/        theme, app_language, text_display
  data/        static content: keyboard_layouts, categories, phrases_data, pictograms
  services/    speech_service (TTS), storage_service (shared_preferences)
  state/       ChangeNotifier controllers: composer, language, phrases, settings
  widgets/     UI; home_page.dart is the root screen
  l10n/        ARB sources (app_en.arb = template, app_cs.arb) + generated app_localizations*.dart
  main.dart    entry point; orientation lock, DI wiring
test/               headless widget/unit tests
integration_test/   device integration suites
planning/           IMPLEMENTATION_PLAN.md + per-feature ADDENDUM plans (design source of truth)
docs/               design notes (e.g. forgiving-taps.md)
handoff/            original handoff archive (_extracted/ is gitignored)
```

## Common commands

```bash
puro flutter run                       # run on connected device/emulator
puro flutter analyze                   # static analysis (fails the build on lint errors)
puro flutter test                      # Dart VM, no device — every test/*_test.dart (fast agent self-check)
puro flutter test integration_test/    # real integration tests (Android only, run manually with -d <device>)
dart run flutter_launcher_icons   # regenerate app icons
dart run flutter_native_splash:create   # regenerate native splash screens
```

Run every command through **Puro** (`puro flutter …` / `puro dart …`); `puro`
is on PATH and auto-selects the `handyspeak` env. The bare `flutter` is not on
PATH (per-env isolation).

Each ADDENDUM suite has a headless `test/<name>_test.dart` and an on-device
`integration_test/<name>_test.dart` sharing one `run…Suite()`. The `test/`
entries let the agent quickly verify logic on the Dart VM; the
`integration_test/` entries are slower and run manually against an Android
device (web unsupported, no desktop folders).

## Conventions

- **Localization:** edit only `lib/l10n/app_en.arb` (template) and
  `app_cs.arb`. Never hand-edit `app_localizations*.dart` — regenerate with
  `puro flutter gen-l10n` (also regenerated on build); the generated files
  are committed.
- **Adding a feature:** put controllers in `lib/state/`, static content in
  `lib/data/`, UI in `lib/widgets/`; wire new controllers into `MultiProvider`
  in `lib/main.dart`.
- **Accessibility-first audience** (motor + speech impairments): for small
  tappable targets use `ForgivingTap` (`lib/widgets/forgiving_tap.dart`), not
  `InkWell.onTap`. Plain `InkWell` cancels a tap once the pointer drifts past
  `kTouchSlop`, which silently drops input for this audience. Full rationale
  and migration list in `docs/forgiving-taps.md`.
- **Per-feature tracking:** substantial features get an ADDENDUM plan in
  `planning/` paired with an integration-test suite in `integration_test/`
  (see the `keytap` and `addendum01` pairs). Follow that shape for new work.
- **Brand color:** `#1fa567`. Theme tokens live in `lib/core/theme.dart`.
