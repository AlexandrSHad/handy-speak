# HandySpeak — ADDENDUM-06: Telemetry (Sentry)

## Context

The app gains error telemetry: native crashes, uncaught Dart/framework
errors, the handled failures our services already swallow silently, and a
small set of startup breadcrumbs. The decision and its privacy posture live
in `docs/adr/0004-telemetry-is-pii-free-diagnostics.md`; the vendor survey
behind it lives in `docs/telemetry-research.md` (dated 2026-10-14 — treat
its vendor facts as point-in-time).

This is **infrastructure plus defensive instrumentation**, not a user-facing
feature: no widget, no setting, no string changes. ADR-0004 deliberately
deferred the Settings toggle, so nothing here touches `settings_dialog.dart`
or the ARB files.

### Decisions taken during the grilling session that produced this plan

- **Sentry SaaS**, org `shad-pro`, project `handy-speak` (EU, `de.sentry.io`)
  — the project already exists; do not create one. `sentry_flutter` pinned
  `^9.30.1` (10.x requires minSdk 26; we keep 24). Dart floor →
  `>=3.5.0 <4.0.0`.
- **One project, one code path.** Environments `development` / `preview` /
  `production` arrive via `--dart-define=SENTRY_ENVIRONMENT=…`, defaulting to
  `development` when absent (the safe fail direction: a mis-tagged release
  lands in the environment we filter out). Alerts are scoped to preview +
  production in the Sentry UI — not code.
- **No DSN → no telemetry.** `SENTRY_DSN` and `SENTRY_ENVIRONMENT` come from
  `--dart-define-from-file=dart_defines.json` (gitignored, at the repo root);
  a committed `dart_defines.example.json` carries empty placeholders. With an
  empty DSN, `SentryFlutter.init` is never called — plain `puro flutter run`,
  `puro flutter test`, and the device smoke stay offline with no mocking.
  A one-line `kDebugMode`-guarded warning prints when the DSN is missing.
- **Signals**: errors + native crashes + ANR + release-health sessions on;
  tracing at `tracesSampleRate` 1.0 in `development`, 0.1 elsewhere (app
  start / slow / frozen frames are the only valuable traces — the app makes
  no network calls). Off: session replay, screenshot / view-hierarchy
  attachment, `sendDefaultPii`, `setUser`, Sentry logs, and the navigator
  observer (single `HomePage`, no routes). **Release is left to the SDK's
  automatic detection** — verify its format during verification; the fallback
  is `kAppVersion` from `lib/core/app_version.dart` (already test-pinned to
  `pubspec.yaml`).
- **Privacy is a code contract** (ADR-0004). Breadcrumbs come only from our
  own code with fixed names and allowlisted metadata:
  `enableUserInteractionBreadcrumbs = false` and
  `enablePrintBreadcrumbs = false` (both default **on** in the SDK — key-tap
  breadcrumbs would spell out a child's message; `print` echoes utterances).
  `beforeBreadcrumb` drops any breadcrumb whose category isn't allowlisted.
  `beforeSend` keeps exception type / code / message and stack traces (they
  are engine- and framework-generated), strips non-allowlisted tags/extras,
  and replaces — with `[redacted]` — the current composer text, its words
  longer than 2 characters, and the last 5 spoken utterances, across the
  exception value, message and extras. Sentry's server-side data scrubbing
  stays on as a backstop.
- **One scope gets message suppression**: the phrases corruption fallback
  (see codebase facts) must not forward its exception message — Dart's
  `FormatException` echoes the offending source text, which there is
  phrase-book content. That scope reports exception **type**, a fixed
  description, and tags only.
- **Instrumentation scope**: every failure path in `speech_service.dart`,
  the phrases corruption fallback, and storage-init failure. Nothing else in
  v1.
- `SENTRY_AUTH_TOKEN` (debug-symbol upload, only if `--obfuscate` is ever
  adopted) is an env var on the build machine, never a define, never
  committed.

### Codebase facts that matter

- **Seven silent `catch (_) {}` blocks**: six in `speech_service.dart`
  (`_init` timeout/throw → `unavailable`; `setLanguage`;
  `hasVoiceFor`; `speak`; `stop`) and one in `phrases_controller.dart:54-56`
  (corrupt stored JSON → falls back to seed phrases — silent data loss of a
  parent's saved phrases).
- `StorageService.init()` (`storage_service.dart:14-16`) can throw and is
  awaited uncaught in `main.dart:31` — the app cannot run without it, but
  today that failure is invisible.
- `SpeechService` already has the `TtsEngine` injection seam
  (`tts_engine.dart`); `test/support/fake_tts_engine.dart` already has
  `hangInit` / `throwOnInit` / `throwOnSpeak` knobs — the canary test only
  needs the thrown *message* to be injectable (it is currently the fixed
  `'speak boom'`).
- `main.dart` ordering is already telemetry-friendly: `storage.init()` runs
  before `runApp`, and `SpeechService` / `ComposerController` are constructed
  in `main()` where a telemetry reference can be handed to them.
- `ComposerController` is a `ChangeNotifier` that notifies on every text
  change — a listener in `main()` can feed the redaction ledger without any
  controller change.
- **No README exists at the repo root** — the run/build documentation home is
  CLAUDE.md's "Common commands" section. (CLAUDE.md's suite-conventions
  paragraph predates `docs/testing-strategy.md` §5's tier layout; refreshing
  it is unrelated to this change and deferred.)
- Test layout today (per `handyspeak-suites` + `docs/testing-strategy.md`):
  Unit mirrors `lib/` under `test/unit/`, Behavior suites are flat files in
  `test/behavior/`, and `integration_test/` holds **only** the device-smoke
  pair. There is no per-feature integration twin and none is created here.

---

## Implementation steps

### 0. Prep — dependency, floor, config plumbing

- `pubspec.yaml`: add `sentry_flutter: ^9.30.1`; environment →
  `sdk: ">=3.5.0 <4.0.0"`.
- `.gitignore`: add `dart_defines.json`.
- Create `dart_defines.example.json` at the repo root:

  ```json
  {
    "SENTRY_DSN": "",
    "SENTRY_ENVIRONMENT": "development"
  }
  ```

Nothing consumes the dependency yet; `puro flutter analyze` and the full
test run must stay green.

### 1. The wrapper — `lib/services/telemetry_service.dart`

A single new file, pure Dart except for the enabled-mode Sentry calls.

**Compile-time config** (const, so a DSN change is a rebuild — accepted):
`String.fromEnvironment('SENTRY_DSN')` and
`String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development')`.
`bool get enabled` = non-empty DSN.

**Internal event model, not Sentry types.** `captureError`,
`addBreadcrumb`, the redaction transform and the allowlists operate on plain
Dart records (`CapturedError {scope, exceptionType, message?, stackTrace?,
tags, extras}`, `CapturedBreadcrumb {name, data}`). `sentry_flutter` types
are touched only by the enabled-mode mapper. This keeps every privacy rule
unit-testable without constructing SDK objects, and gives tests a seam for
free.

**Public API** (shaped so free text is structurally awkward — ADR-0004):

```dart
Future<void> captureError(Object error, StackTrace? stackTrace,
    {required String scope, Map<String, String> tags = const {}});
void addBreadcrumb(String name, {Map<String, Object?> data = const {}});
void registerSecret(String text);      // composer text, current
void registerUtterance(String text);   // spoken, ring buffer of 5
```

**Allowlists** (private consts, one place each):

- Tag keys: `ui_locale`, `main_lang`, `second_lang`,
  `tts_engine_available`, `tts_status`, `tts_error_code`, `phrases_lang`,
  `raw_length`. Anything else is dropped in `beforeSend`.
- Breadcrumb names: `app_start`, `tts_status`, `tts_language`. Anything else
  is dropped in `beforeBreadcrumb`.

**Redaction transform** (`SentryEvent`-side and sink-side share it): collect
the secret set = current composer text + its words of length ≥ 3
(`kRedactMinWordLength = 3`, one named tunable — the ">2 characters" rule as
a constant we can raise if diagnostics get over-redacted) + the utterance
ring buffer (last 5, evict oldest). Replace every occurrence with
`[redacted]` across exception value, exception message, event message and
extras. Scope policy: scopes named in a `const _suppressMessageScopes =
{'phrases/load_corrupt'}` emit exception **type** + fixed description +
tags, never the raw message.

**Sink.** A bounded in-memory recorder (last 20 captured errors/breadcrumbs,
**post-redaction**) that records in *both* modes — this is the canary-test
seam; in disabled mode it is the only thing that happens. Exposed
`@visibleForTesting`.

**Error hooks.** `installErrorHooks()` routes `FlutterError.onError` and
`PlatformDispatcher.instance.onError` into `captureError` (scope
`framework/render` and `platform` respectively) in both modes — render
errors can embed `Text` widget contents, so they flow through the same
redaction, and the canary test can drive a real framework error headlessly.

**Init.** `SentryOptions configure(SentryOptions options)` (enabled mode
only): `dsn`, `environment`, `tracesSampleRate =
environment == 'development' ? 1.0 : 0.1`,
`enableAutoSessionTracking = true`, `enableTimeToInitialDisplay = true`,
`enableUserInteractionBreadcrumbs = false`, `enablePrintBreadcrumbs = false`,
`sendDefaultPii = false`, `beforeSend` / `beforeBreadcrumb` wired to the
transforms above. **No** `release`, **no** `setUser`, **no** navigator
observer, **no** replay/screenshot/view-hierarchy flags (they default off;
leave them off). ANR comes with the Android layer — confirm during
verification rather than configuring.

**Disabled warning.** `void warnIfDisabled()` → one `debugPrint` line, called
from `main()` in disabled mode only, `kDebugMode`-guarded.

### 2. Wiring — `lib/main.dart`

```dart
Future<void> main() async {
  final telemetry = TelemetryService();
  Future<void> run() async { /* the entire existing body, plus: */ }

  if (telemetry.enabled) {
    await SentryFlutter.init(telemetry.configure, appRunner: run);
  } else {
    telemetry.warnIfDisabled();
    await run();
  }
}
```

Inside `run()`:

- **Storage-init capture**: wrap `await storage.init()` in a try/catch that
  calls `captureError(e, st, scope: 'storage/init', tags: {'stage':
  'prefs'})` — no, `stage` is not allowlisted; tags stay empty — then
  **rethrows**. The app cannot run without storage; the capture adds context
  before the crash surfaces.
- `SpeechService(engine: FlutterTtsEngine(), telemetry: telemetry)`.
- After `composer` is constructed:
  `composer.addListener(() => telemetry.registerSecret(composer.text));`
  — zero changes to `ComposerController`.
- `telemetry.installErrorHooks()` before `runApp`.
- Startup breadcrumb: `telemetry.addBreadcrumb('app_start', data: {
  'ui_locale': …, 'main_lang': …, 'second_lang': … })` after
  `language.load(...)` resolves (values then known; metadata only).
- **Not** registered in `MultiProvider` — no widget consumes it (ADR-0004
  deferred the toggle).

### 3. Instrument — `lib/services/speech_service.dart`

Constructor gains `TelemetryService? telemetry`, defaulted to a no-op
instance so every existing construction site and test stays unchanged.

- `speak()`: `telemetry.registerUtterance(text)` first (even when not ready —
  a dropped utterance is still a secret worth redacting), then the existing
  `catch (e)` (currently `catch (_)`) calls
  `captureError(e, st, scope: 'tts/speak')`.
- `_init()` catch: `captureError(e, st, scope: 'tts/init', tags: {
  'tts_status': 'unavailable' })`; then, in `finally`, the existing
  `notifyListeners()` gains a `telemetry.addBreadcrumb('tts_status', data:
  {'tts_status': status.name})` — one breadcrumb per settled init, not per
  listen.
- `setLanguage()` catch: `scope: 'tts/set_language'`, tags
  `{'ui_locale': _locale}` (locale code only — never content).
- `hasVoiceFor()` catch: `scope: 'tts/voices'`.
- `stop()` catch: `scope: 'tts/stop'`.
- On a successful `setLanguage` (the ready path), `addBreadcrumb(
  'tts_language', data: {'ui_locale': locale})`.

Scope strings are string-literal consts at each call site — the wrapper's
`scope` parameter is the only free-text-shaped argument, and it is pinned
per site by convention + asserted allowlisted in `beforeSend` (unknown
scope → tags-only event).

### 4. Instrument — `lib/state/phrases_controller.dart`

Constructor gains `TelemetryService? telemetry` (same defaulting pattern).
The `load()` corruption catch becomes:

```dart
} catch (e, st) {
  _byLang[lang] = List.of(kSeedPhrases[lang] ?? const []);
  telemetry.captureError(e, st, scope: 'phrases/load_corrupt',
      tags: {'phrases_lang': lang.key, 'raw_length': raw.length});
}
```

`phrases/load_corrupt` is in `_suppressMessageScopes` — the `FormatException`
message echoes the raw JSON (i.e. the phrase text) and must not ship; the
event carries type + tags only. `raw_length` is a number, never content.

### 5. Docs — `CLAUDE.md`

"Common commands" gains:

```bash
puro flutter run --dart-define-from-file=dart_defines.json   # telemetry on (fill DSN first)
puro flutter build apk --release --dart-define-from-file=dart_defines.json
```

plus one line under Conventions: the DSN is public-by-design but never
committed; `dart_defines.json` is gitignored, the example file is the
template; `SENTRY_AUTH_TOKEN`, if ever needed for symbol upload, is an env
var only. There is no README at the root — creating one is out of scope.

### 6. Tests

Per the `handyspeak-suites` skill and `docs/testing-strategy.md` — no
integration twin; the device smoke is untouched (it never gets a DSN, so
telemetry is inert on device tests by construction).

**Unit — `test/unit/services/telemetry_service_test.dart`** (new file,
mirrors the source):

- No-DSN no-op: `enabled == false`; `configure` never runs; sink records but
  nothing can send.
- Environment resolution: absent define → `development`; explicit → honored.
- Redaction transform, case by case: full composer string; word ≥ 3 chars;
  1–2-char words untouched; utterance eviction at 5; `[redacted]` applied
  across exception value/message/extras; non-allowlisted tags and extras
  stripped; allowlisted ones survive.
- `beforeBreadcrumb` drops non-allowlisted names.
- `phrases/load_corrupt` suppresses the message (exception type + tags
  only) even when the message contains a canary.
- Unknown scope → tags-only event.

**Unit — `test/unit/services/speech_service_test.dart`** (extend): with
`hangInit` / `throwOnInit` / `throwOnSpeak`, the sink receives exactly one
error per failure with the right scope and `tts_status` tag; a settled init
emits exactly one `tts_status` breadcrumb (ready and unavailable both);
utterances land in the ledger (assert via a later redaction).

**Unit — `test/unit/state/phrases_controller_test.dart`** (extend): corrupt
stored JSON (existing case) now also produces a `phrases/load_corrupt`
capture with `phrases_lang` + `raw_length` and **no** JSON content anywhere
in the captured payload.

**Behavior — `test/behavior/telemetry_test.dart`** (new file, on
`test/support/app_harness.dart`): the canary suite from ADR-0004 —

1. Type `CANARYQQ7X` via real keyboard taps; make the harness `FakeTts`
   throw on `speak` with a message embedding the canary (add an injectable
   failure message to the fake — the unit-tier `FakeTtsEngine` gains the
   same knob); tap Speak. Assert a `tts/speak` capture exists in the sink
   and the canary appears in **no** recorded payload (error, breadcrumb,
   tags, extras — serialized and searched).
2. Force a real framework error whose render tree contains the canary
   (e.g. a `Text(canary)` in an overflowing constraint inside the pumped
   app's error path); assert the `framework/render` capture is redacted.
3. Seed `phrases_en` with corrupt JSON embedding the canary; boot; assert
   the `phrases/load_corrupt` capture exists and contains no canary.
4. Healthy boot emits `app_start` + `tts_status` breadcrumbs with allowlisted
   metadata only.

---

## Commit sequence

1. **Prep**: pubspec + floor bump + gitignore + example defines file
   (step 0). Additive only; everything green.
2. **Wrapper**: `telemetry_service.dart` + its unit tests (steps 1). Not yet
   referenced by `lib/main.dart`.
3. **Wiring**: `main.dart` + hooks + ledger listener (step 2). The behavior
   canary suite lands here (step 6, telemetry file) — the harness fake
   extension rides along.
4. **Instrumentation**: `speech_service.dart` + `phrases_controller.dart`
   and their unit-test extensions (steps 3–4, 6).
5. **Docs**: CLAUDE.md commands + conventions line (step 5).

## Risks

- **Auto-release format unverified.** `sentry_flutter` 9.x derives release
  from the Android layer's `versionName`; it may render bare (`0.7.0`) or
  prefixed. Verify in the manual pass; the fallback is setting
  `release: 'handy_speak@$kAppVersion'` — one line, decided then.
- **Over-redaction mangles diagnostics.** Words ≥ 3 chars from the composer
  are replaced everywhere; a child who typed "the" will redact "the" from
  every message for the session. `kRedactMinWordLength` is the single knob;
  raise it (5 is the likely next value) if verification shows noise.
- **`FormatException` is not the only echoer.** Other exception types may
  embed input (plugin messages). The canary suite covers TTS, framework
  and phrases paths; if a new scope ever forwards risky messages, add it to
  `_suppressMessageScopes` — never redact harder globally.
- **SDK native layer on old tablets.** `SentryFlutter.init` adds native
  setup before `runApp`. It is async and non-blocking by design; if the
  splash-to-first-frame time regresses measurably on a slow device, init
  telemetry *after* the first frame instead (the hooks install later; lost
  pre-init crashes accepted).
- **`String.fromEnvironment` is const.** Changing DSN or environment is a
  rebuild, not a rerun. Accepted; the define file makes it a one-flag
  rebuild.
- **Quota burn by accident.** A filled `dart_defines.json` left in place
  sends dev events. Mitigation: the file is opt-in, dev environment is
  filtered in the UI, and spike protection is on server-side.

## Verification

### Unit / Behavior (green gate)

- [ ] `puro flutter analyze` clean.
- [ ] `puro flutter test` green — including the three extended files and the
      two new ones; **no DSN anywhere in test code**.
- [ ] The canary suite red if any canary reaches any sink payload.

### Manual (with a real DSN — the ADR's "verification step")

- [ ] Fill `dart_defines.json` with the project DSN, `SENTRY_ENVIRONMENT` =
      `development`; `puro flutter run --dart-define-from-file=…`.
- [ ] Sentry (de.sentry.io, project handy-speak) shows: a session, the
      `app_start` + `tts_status` breadcrumbs, environment `development`, and
      the auto-release format. If release is bare or missing, set
      `handy_speak@kAppVersion` and note it here.
- [ ] Trigger one real TTS failure path on-device (e.g. temporarily point
      `setLanguage` at an unsupported locale in a scratch branch) and confirm
      the issue arrives with readable frames.
- [ ] Confirm ANR detection presence/absence in project settings; record the
      knob if it needs configuring.
- [ ] Remove the scratch changes; empty the DSN in the local define file.

### Release checklist (when a build ships)

- [ ] `SENTRY_ENVIRONMENT` = `preview` (sideload/tester) or `production`
      (Play); DSN present; build made **with** `--dart-define-from-file`.
- [ ] Play Data safety form declares "Crash logs" only (first Play
      submission).
- [ ] No `--obfuscate` today → no `sentry_dart_plugin`; revisit both
      together.

### AAC checklist

- [ ] Nothing child-facing changes: no UI, no touch targets, no strings.
      Telemetry is invisible to the child by design (ADR-0004); the only
      parent-visible artifact is the privacy policy at store-listing time.

## Deferred (explicitly out of scope)

- **The Settings toggle** (ADR-0004 considered-and-deferred): "Send error
  reports", default on, storage-pref gate beside DSN presence, effective on
  next app start. Add as a reversible surface if ever demanded.
- `sentry_dart_plugin` + `--obfuscate` symbol upload; `SENTRY_AUTH_TOKEN`
  plumbing with it.
- CI writing the define file from secrets (no CI exists).
- README at the repo root; CLAUDE.md suite-conventions paragraph refresh
  (stale vs `docs/testing-strategy.md` §5, pre-existing).
- Product analytics of any kind (ADR-0004 rejection); GlitchTip migration
  (a DSN swap when wanted); iOS specifics (same project, OS is a tag —
  revisit safe-area/touch notes only if the smoke gains an iOS pass).

## Critical files

- `docs/adr/0004-telemetry-is-pii-free-diagnostics.md`
- `docs/telemetry-research.md`
- `pubspec.yaml`
- `.gitignore`
- `dart_defines.example.json` (new)
- `lib/services/telemetry_service.dart` (new)
- `lib/services/speech_service.dart`
- `lib/state/phrases_controller.dart`
- `lib/main.dart`
- `CLAUDE.md`
- `test/unit/services/telemetry_service_test.dart` (new)
- `test/unit/services/speech_service_test.dart`
- `test/unit/state/phrases_controller_test.dart`
- `test/behavior/telemetry_test.dart` (new)
- `test/support/fake_tts_engine.dart` (+ harness `FakeTts` failure-message knob)
