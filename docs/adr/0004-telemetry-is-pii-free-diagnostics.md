# Error telemetry is PII-free diagnostics via Sentry

The app ships to children who cannot report bugs — a non-verbal user has no
way to say "TTS broke," and their parent sees only "the button doesn't work."
We decided to add error telemetry (native crashes, handled failures such as
TTS engine errors, and a few startup breadcrumbs) so those failures become
fixable. Vendor: **Sentry SaaS** (org `shad-pro`, EU region), chosen over
Firebase Crashlytics and self-hosted GlitchTip in `docs/telemetry-research.md`.
Because the Sentry wire protocol is an open surface, GlitchTip remains a
DSN-swap exit ramp — the vendor choice is deliberately cheap to reverse.

The SDK is pinned to `sentry_flutter` **9.x** (`^9.30.1`), not 10.x: 10.0.0
raises the minimum Android API to 26, and this app keeps `minSdk` 24 because
the audience skews toward old, cheap tablets. Moving to 10.x is therefore a
product decision (dropping Android 7), not a routine upgrade — do not "fix"
the pin by bumping `minSdk`. The pubspec Dart floor moves to `>=3.5.0` to
satisfy 9.x.

The load-bearing decision is that telemetry is **PII-free diagnostics by
construction, never consent-based processing and never product analytics**.
The app collects crash and error metadata with no user or device identity and
no message content, which keeps the lawful basis legitimate interest and the
Play Data safety declaration to "Crash logs" only. This posture is a code
contract, not a convention: composer text, phrase-book contents and symbol
words never enter events; breadcrumbs and tags are allowlisted; the SDK's
user-interaction and print breadcrumbs are disabled (key-tap breadcrumbs
would spell out a child's message keystroke by keystroke); `beforeSend`
redacts known user strings (current composer text, its words, recent
utterances) from anything that does ship; and a canary test fails the build
if user text reaches a captured payload. `setUser` and `sendDefaultPii` are
never called; session replay, screenshots and view hierarchies stay off.

Telemetry is active **only when a DSN is injected at build time**
(`--dart-define-from-file=dart_defines.json`, gitignored; a committed
`dart_defines.example.json` carries placeholders). With no DSN, the
`TelemetryService` wrapper is inert and `SentryFlutter.init` is never called,
so plain dev runs and every test tier are offline by construction — no
mocking needed. One Sentry project serves all environments, separated by the
`environment` tag (`development` / `preview` / `production`); the release
identifier is left to the SDK's automatic detection.

Considered and deferred: a parent-facing "Send error reports" toggle in
Settings (default on). Visible control would be the cheapest answer to any
future demand to stop processing, but it is not required for crash logs and
can be added later as a reversible surface — the init condition would simply
gain a storage-pref gate beside DSN presence. Also deferred: Firebase
Crashlytics (revisit only if the app adopts Firebase anyway) and any
product-analytics platform (PostHog, Countly) — rejected as a heavier privacy
surface than a children's AAC app should carry.

Implementation plan: `planning/ADDENDUM-06-telemetry-plan.md`.
