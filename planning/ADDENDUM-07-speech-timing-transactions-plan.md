# HandySpeak — ADDENDUM-07: Speech timing transactions

## Context

The app's only performance trace today is the SDK-generated app-start one
(`ui.load` root with the `app.start.cold` span breakdown). For a speaking
app the latency that actually matters is invisible: **how long between the
child tapping Speak and sound coming out**, and how long after launch the
Speak button stays disabled. Errors in those paths already report
(ADDENDUM-06); the silent "works but takes 900 ms" case does not.

This addendum adds **two transactions** — `tts/speak` and `tts/ready` —
measured with sentry_flutter's manual tracing API (there is still no
navigator observer, by ADR-0004's minimalism). Like ADDENDUM-06 this is
infrastructure, not a user-facing feature: no widget, no setting, no
strings, no permissions.

ADR-0004 ("telemetry is PII-free diagnostics") is **unchanged** — timing
data is diagnostics. This addendum extends its code contract to the
transaction pipeline, where one technical difference matters: **`beforeSend`
does not run on transactions.** The error pipeline scrubs tags in
`beforeSend`; the transaction pipeline must therefore filter **at creation
time**, inside the `TelemetryService` seam, before any Sentry type exists.

### Decisions taken during the design conversation that produced this plan

- **Two transactions only.** `tts/speak` (per main-channel Speak tap) and
  `tts/ready` (per launch). Everything else proposed — phrase save/load
  spans, `tts/set_language` timing — is deferred (see end).
- **The finish line of `tts/speak` is first sound, not enqueue.**
  `SpeechService.speak()` resolves when the utterance is enqueued; the
  engine's start callback (`onSpeakingStateChanged(true)`) is when audio
  actually begins. The transaction spans tap → start callback. Speech
  *duration* after that is engine-driven and not actionable — out of scope.
- **Main-channel utterances only.** Typing-feedback utterances (letter
  echo, word echo, symbol/phrase confirmation) never start transactions:
  they are high-volume and their timing pattern mirrors the child's typing
  cadence — the same reasoning that disabled user-interaction breadcrumbs
  in ADDENDUM-06.
- **No text in transactions, ever.** Transaction names are fixed scope
  strings from an allowlist; child-span names are fixed string literals at
  their (two) call sites — the same pinning convention as ADDENDUM-06
  error scopes. Tags are filtered to the allowlist at creation. The
  utterance itself keeps flowing only into the redaction ledger
  (`registerUtterance`), unchanged.
- **One new tag key**: `speak_outcome` (values `spoken`, `error`,
  `superseded`, `stopped`, `timeout`). `tts/ready` reuses the existing
  `tts_status` key (`ready` / `unavailable`). `raw_length` (character
  count) and `ui_locale` (engine locale code) already exist in the
  allowlist.
- **Sampling stays as-is** — `tracesSampleRate` 1.0 in `development`,
  0.1 elsewhere (ADDENDUM-06). With real transactions this rate changes
  meaning from "drops 90 % of the only trace" to a sane budget: a child
  tapping Speak ~50×/day keeps ~5 `tts/speak` transactions/day in
  production. Revisit only with data.
- **No new Data-safety categories.** Spans are content-free timings; the
  Play declaration needed for what *already ships* (sessions, app-start
  traces, the SDK's per-install UUID) already covers anything this
  addendum emits. One correction rides along: ADDENDUM-06's release
  checklist line "Play Data safety form declares 'Crash logs' only" was
  under-declared — see §5.
- **No new ADR.** Same posture as ADR-0004, same vendor, same DSN plumbing.

### Codebase facts that matter

- `SpeechService.speak()` (`speech_service.dart`): register-utterance →
  readiness/empty guards → `_setSpeaking(false)` → `stop()` → optional
  rate/pitch → `speak()`. The **start callback arrives via
  `_onEngineSpeakingState`**, gated on `_mainUtterance == true` — i.e. the
  service already routes exactly the event we finish the transaction on,
  for exactly the utterances we trace.
- `FlutterTtsEngine` collapses the plugin's five handlers (start /
  completion / cancel / pause / **error**) into one boolean signal. A
  playback *error* is indistinguishable from normal completion in the
  service today — so v1 outcomes cannot include `playback_error`. Splitting
  the error handler out of the collapse is a seam change deferred with the
  rest (it would also fix `_onEngineSpeakingState`'s blind spot).
- `setLanguage()` is **not** part of `speak()` — language switching happens
  in `LanguageController` before the tap can occur. No `tts/set_language`
  child span belongs inside `tts/speak`.
- `_initTimeout` (16 s) already bounds `tts/ready` from above: status
  settles to `ready` or `unavailable`, `notifyListeners()` fires, no
  listener gymnastics needed beyond a one-shot.
- `main.dart` already wires cross-cutting listeners in `run()`
  (`composer.addListener(...)` for the redaction ledger) — the `tts/ready`
  one-shot finisher follows that exact pattern; `SpeechService` stays
  unaware of it.
- `FakeTtsEngine` (`test/support/fake_tts_engine.dart`) already has
  `emitSpeakingState(bool)` and fires `true` → `false` around a successful
  `speak()` — the `spoken` outcome is testable with zero fake changes.
  `hangInit` / `throwOnInit` / `throwOnSpeak` cover the other outcomes.
- Test layout (per `handyspeak-suites` + `docs/testing-strategy.md`): Unit
  mirrors `lib/` under `test/unit/`, Behavior files live in `test/behavior/`
  named by feature slug, `integration_test/` holds only the device-smoke
  pair — untouched here (no DSN on device tests, telemetry inert by
  construction).

---

## Implementation steps

### 1. The seam — `lib/services/telemetry_service.dart`

One new public type plus allowlist/sink extensions, mirroring the
ADDENDUM-06 error API shape (internal model, Sentry types only in
enabled-mode):

```dart
TelemetryTransaction startTransaction(String scope,
    {Map<String, String> tags = const {}});

class TelemetryTransaction {
  TelemetrySpan child(String name);                    // fixed-literal names
  void setTag(String key, String value);               // allowlist-filtered
  void finish({Map<String, String> tags = const {}});  // idempotent
  bool get isFinished;                                 // caller-side guard
}
```

- **Scope allowlist**: `_transactionScopeAllowlist = {'tts/speak',
  'tts/ready'}` — a *separate* const from the error scopes (different
  pipeline, different failure mode). Unknown scope → the handle is a
  born-finished no-op and the rejection is recorded in the sink, so a
  future typo'd scope fails a test, not silently.
- **Tag filtering at creation and at every `setTag`/`finish`** — the
  `beforeSend` backstop does not exist for transactions (see Context).
  Same `tagKeyAllowlist` as errors, plus `speak_outcome`.
- **Sink**: `recordedTransactions` (last 20, both modes,
  `@visibleForTesting`), recording `CapturedTransaction {scope, tags,
  childNames}` post-filter — the canary seam, identical contract to the
  error/breadcrumb sinks.
- **Disabled mode**: the handle records to the sink and does nothing else;
  callers never branch on `enabled`.
- **Enabled mode**: `Sentry.startTransaction(scope, 'app')`, children via
  `startChild`, tags set before finish. `finish` is idempotent (the SDK
  would throw on double-finish; the wrapper swallows instead).

### 2. `tts/speak` — `lib/services/speech_service.dart`

- Add `static Duration speakTxTimeout = const Duration(seconds: 10);`
  (mutable static, `@visibleForTesting` on the mutability — the tunable if
  verification shows timeout noise).
- Field `TelemetryTransaction? _speakTx`; helper `_finishSpeak(String
  outcome)` that finishes-and-nulls if open.
- In `speak()`, **after** the guards pass and **before** the engine calls
  (any new utterance that reaches the engine ends the previous one's reign):
  - `_finishSpeak('superseded')` — this covers *both* a rapid second Speak
    tap and a typing-feedback utterance preempting a pending main one
    (QUEUE_FLUSH means the pending utterance's start event will never
    arrive);
  - if `feedback == false`: start `_speakTx =
    telemetry.startTransaction('tts/speak', tags: {'ui_locale': _locale,
    'raw_length': text.length.toString()})`, plus child spans `stop`
    (preempt) and `submit` (`engine.speak`) as fixed literals;
  - arm the timeout `Timer` (cancelled in `_finishSpeak`), finishing with
    `speak_outcome: 'timeout'`.
- In `_onEngineSpeakingState(true)` (the `_mainUtterance` branch):
  `_finishSpeak('spoken')`. The `(false)` branch does nothing — once audio
  started, the measurement is done.
- In `speak()`'s catch: `_finishSpeak('error')` (existing
  `captureError(scope: 'tts/speak')` stays — error event + timing
  transaction are complementary, not redundant).
- In `stop()`: `_finishSpeak('stopped')`.
- Early returns (not-ready / empty text) leave an open transaction to the
  timeout — accepted: the UI gates the button, so those paths are
  defensive-only.

### 3. `tts/ready` — `lib/main.dart`

At the top of `run()`, before `storage.init()` (the child's wait covers
storage too — that is the honest number):

```dart
final readyTx = telemetry.startTransaction('tts/ready');
```

and right after `SpeechService` construction, the one-shot finisher
(mirrors the ledger-listener pattern):

```dart
void readyListener() {
  if (speech.status == SpeechStatus.initializing) return;
  speech.removeListener(readyListener);
  readyTx.finish(tags: {'tts_status': speech.status.name});
}
speech.addListener(readyListener);
```

`_initTimeout` guarantees settle-or-fail within 16 s; a storage-init crash
leaves the transaction unfinished → Sentry drops it (correct: the app never
ran).

### 4. Tests

Per `handyspeak-suites` — extend existing feature files, no integration
twin, device smoke untouched.

**Unit — `test/unit/services/telemetry_service_test.dart`** (extend):

- Unknown scope → born-finished no-op + rejection recorded in sink.
- Tags: non-allowlisted key dropped at creation and at `setTag`;
  `speak_outcome` accepted; double `finish` ignored (idempotent).
- Sink records transactions in both modes, post-filter (no key that isn't
  allowlisted appears in `CapturedTransaction.tags` / child names).

**Unit — `test/unit/services/speech_service_test.dart`** (extend, on
`FakeTtsEngine` — needs no new knobs):

- Successful main speak → transaction finishes `spoken`, tags carry
  `ui_locale` + `raw_length`, children `stop`/`submit` recorded.
- `feedback: true` speak → **no** transaction started.
- `throwOnSpeak` → `error` outcome (and the existing error capture).
- Main speak then second main speak before any start event → first
  `superseded`, second open.
- Main speak then feedback speak → open one `superseded`.
- `stop()` before start event → `stopped`.
- Timeout: set `SpeechService.speakTxTimeout = 50 ms`, never emit the
  start state → `timeout` (restore in teardown).

**Behavior — `test/behavior/telemetry_test.dart`** (extend the canary
suite): type `CANARYQQ7X`, tap Speak (harness `FakeTts`), assert a
`tts/speak` transaction exists in the sink and the canary appears in **no**
recorded payload — transactions serialized and searched alongside errors
and breadcrumbs. Healthy boot → `tts/ready` finishes `ready`;
`hangInit`-style init failure → `unavailable`.

- **Harness check**: `FakeTts` mocks the `flutter_tts` method channel; if
  it does not emit the plugin's start event back through the channel,
  the behavior canary can only assert the `superseded`/`timeout` paths —
  then the `spoken` path stays unit-tier and the canary asserts the
  *redaction* via `superseded`. Decide at implementation; if the fake
  gains an event push, add the happy path.

### 5. Docs — release-checklist correction

- This addendum's release checklist (below) supersedes ADDENDUM-06's
  "Play Data safety form declares 'Crash logs' only (first Play
  submission)" line. The corrected set for what already ships today:
  **Crash logs, Diagnostics, Other app performance data** (App info and
  performance) and **Device or other IDs** (the SDK's anonymous per-install
  UUID used by release health). Nothing in this addendum adds a category.
- No CLAUDE.md command changes (same define file, same build flags).

---

## Commit sequence

1. **Seam**: transaction handle + allowlists + sink in
   `telemetry_service.dart`, with the unit-test extensions. Not yet
   referenced by `lib/main.dart` or `speech_service.dart`.
2. **`tts/speak`**: `speech_service.dart` instrumentation + unit tests.
3. **`tts/ready`**: `main.dart` wiring + behavior canary extensions.
4. **Docs**: the checklist correction rides with 3 (or its own trivial
   commit).

## Risks

- **Engine start-callback granularity.** Some Android TTS implementations
  fire `start` late or never for very short utterances; those land as
  `timeout`. Mitigation: `speakTxTimeout` is the single tunable; monitor
  the `speak_outcome` distribution in Sentry and raise it before
  distrusting the data.
- **Playback errors are invisible to the outcome.** The five-handler
  collapse in `FlutterTtsEngine` maps engine errors to `speaking = false` —
  indistinguishable from completion (pre-existing, not introduced here).
  A `playback_error` outcome requires splitting the error handler out of
  the collapse; deferred with a note.
- **Volume/quota.** Speak is the primary button of an AAC app; development
  runs at 1.0 sampling. A heavy manual-test session sends one transaction
  per tap. Accepted (dev environment is filtered in the UI); production's
  0.1 caps it structurally.
- **Unfinished transactions on process kill.** Sentry drops them — a
  force-kill mid-tap loses that sample. Accepted; sampling is already
  probabilistic.
- **Slow/frozen-frame measurements attach automatically** to any
  transaction (`enableAutoPerformanceTracing`, already on). This is a
  feature (jank during Speak becomes visible), not a risk — noted so the
  extra payload on `tts/speak` in the Sentry UI is not a surprise.

## Verification

### Unit / Behavior (green gate)

- [ ] `puro flutter analyze` clean.
- [ ] `puro flutter test` green — the two extended unit files and the
      extended canary suite; no DSN anywhere in test code.
- [ ] Canary red if any canary reaches any sink payload — **including
      `recordedTransactions`**.

### Manual (with a real DSN)

- [ ] `dart_defines.json` with DSN, `SENTRY_ENVIRONMENT = development`;
      `puro flutter run --dart-define-from-file=dart_defines.json`.
- [ ] Tap Speak: Sentry Performance → a `tts/speak` transaction with
      children `stop`/`submit`, tags `ui_locale`/`raw_length`/
      `speak_outcome=spoken`, and slow/frozen-frame counts attached.
- [ ] Rapid double-tap Speak → one `spoken` + one `superseded`.
- [ ] Fresh launch → one `tts/ready` transaction with `tts_status=ready`.
- [ ] Spans view (filter op `app`, environment `development`): p50/p95 of
      `tts/speak` over ~10 taps; record the ballpark here for the
      baseline. Expect seconds-scale on debug builds (JIT) — baseline
      against a `--profile` run, not debug.
- [ ] Leave `--profile --dart-define=SENTRY_ENVIRONMENT=preview` sampling
      as-is: after ~20 preview launches/taps expect the first preview rows
      (10 % Bernoulli per transaction); do not "fix" this — it is the
      configured budget.
- [ ] Empty the DSN in the local define file afterwards.

### Release checklist (when a build ships)

- [ ] Play Data safety (supersedes ADDENDUM-06's line): Crash logs +
      Diagnostics + Other app performance data + Device or other IDs;
      encrypted in transit; not shared; this addendum adds no category.
- [ ] iOS (future): same transactions work — `setStartHandler` is
      supported by flutter_tts on iOS; no platform branch in the seam.

### AAC checklist

- [ ] Nothing child-facing changes: no UI, no touch targets, no strings,
      no permissions. The only new network traffic is the child's own
      tap-to-sound latency, without the tap's content.

## Deferred (explicitly out of scope)

- **`tracesSampler` keeping app-start at 100 %** (the conversation's
  original question) — sampling deliberately left as-is; one-line change
  with data to justify it.
- **`phrases.save` / `phrases.load` spans** — storage writes, not a
  user-felt unit of work; revisit if phrase lists ever grow into jank.
- **`tts/set_language` timing** — error capture exists; timing only if
  dual-language switching shows complaints.
- **`playback_error` outcome** — requires splitting the error handler out
  of `FlutterTtsEngine`'s five-handler collapse (a `TtsEngine` seam
  change); do it together with any other engine-event work.
- **Sentry dashboards/alerts** on `tts/speak` p95 or `timeout` rate —
  UI-side configuration, not code.
- **Letter-echo latency** — never (privacy: typing cadence).

## Critical files

- `docs/adr/0004-telemetry-is-pii-free-diagnostics.md` (governing ADR, unchanged)
- `planning/ADDENDUM-06-telemetry-plan.md` (sibling; release-checklist line corrected by §5)
- `lib/services/telemetry_service.dart`
- `lib/services/speech_service.dart`
- `lib/main.dart`
- `test/unit/services/telemetry_service_test.dart`
- `test/unit/services/speech_service_test.dart`
- `test/behavior/telemetry_test.dart`
- `test/support/fake_tts_engine.dart` (expected: no change needed)
- `test/support/app_harness.dart` (possible `FakeTts` event push — see §4)
