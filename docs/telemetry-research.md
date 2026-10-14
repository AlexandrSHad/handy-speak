# Telemetry options research — crash/error reporting for HandySpeak

**Question:** add telemetry so bugs/issues can be investigated and fixed without
waiting for user reports. Free tier strongly preferred; paid services only if
they earn their keep.

**Date:** 2026-10-14. All vendor facts below were checked against primary
sources (official docs / pricing pages / package metadata / SDK sources) on
this date; each claim links its source. Unverified items are marked as such.

## TL;DR

**Recommendation: Sentry SaaS on the free Developer plan**, using
`sentry_flutter` **9.30.1** (keeps the current Android floor; see
compatibility below), wired through a `lib/services/telemetry_service.dart`
wrapper with the DSN injected via `--dart-define`, `sendDefaultPii` left off,
and a hard rule that **composer text never enters telemetry**.

- Runner-up: **Firebase Crashlytics** if you expect to adopt Firebase anyway
  later (remote config, etc.) — unlimited crashes at no cost, minSdk 21.
- Exit ramp / data-sovereignty option: **GlitchTip** (open-source,
  Sentry-API-compatible — same Flutter SDK, just a different DSN, self-hosted
  or 1k events/mo hosted free).
- Skip product-analytics platforms (PostHog, Countly) for now — bigger privacy
  surface than the goal needs. Skip Bugsnag (retention-limited free tier),
  Embrace (paid, $80/mo minimum), and anything App Center (service retired).

## What HandySpeak actually needs from telemetry

The goal is *error monitoring*, not product analytics:

1. **Native crashes** (uncaught, out-of-Dart-VM).
2. **Handled errors** — e.g. TTS engine failures in
   `lib/services/speech_service.dart` (engine missing, language not available,
   init failure) — exactly the bugs users can't report.
3. **Context to reproduce**: app version, Android/API level, locale set,
   whether TTS engine/data are present. Enough breadcrumbs to reconstruct the
   path to the error — without ever capturing message content.

### Project constraints (verified in-repo)

| Constraint | Value | Source |
|---|---|---|
| Existing telemetry | none — deps are only tts/provider/prefs/intl | `pubspec.yaml` |
| Toolchain (Puro `handyspeak`) | Flutter 3.44.4 / Dart 3.12.2 | `puro flutter --version` |
| pubspec Dart floor | `>=3.4.0 <4.0.0` | `pubspec.yaml` |
| Android `minSdk` | `flutter.minSdkVersion` = **24** in Flutter 3.44 | `android/app/build.gradle.kts` + `FlutterExtension.kt` in the SDK |
| iOS | deferred (no Mac); Android-only today | `CLAUDE.md` |
| Audience | children with motor/speech impairments — often older/cheaper tablets | `CLAUDE.md`, `docs/forgiving-taps.md` |

The minSdk point matters: the audience skews toward old hardware, so dropping
Android 5–7 support to satisfy an SDK is a real product decision, not a
footnote.

## Candidate-by-candidate findings

### 1. Sentry (recommended)

**Pricing (free tier):** the [pricing page](https://sentry.io/pricing/) shows a
"Free Developer Plan" — *5k errors/month* on the Developer plan (50k on
Business), plus "5,000 Session Replays per month for your first 3 months" as a
new-user trial. Verified from the page HTML on 2026-10-14.

**Flutter SDK compatibility — the critical detail:**

| sentry_flutter | Dart SDK | Android requirement | iOS |
|---|---|---|---|
| 10.0.0 (latest) | `>=3.12.0` | **API 26+** ("set minSdk to 26 or higher") | iOS 15+ |
| 9.30.1 (last 9.x) | `>=3.5.0` | API 21+ (bump only landed in 10.0.0) | — |
| 8.14.2 (last 8.x) | `>=3.4.0` | API 21+ | — |

Sources: [pub.dev API](https://pub.dev/packages/sentry_flutter) version
metadata (Dart constraints), [Sentry Flutter docs prerequisites]
(https://docs.sentry.io/platforms/flutter/) ("A Flutter application using
Flutter 3.44.0 and Dart 3.12.0 or later", "Android API 26 or later…
iOS 15.0"), and the [sentry-dart CHANGELOG]
(https://github.com/getsentry/sentry-dart/blob/main/CHANGELOG.md): 10.0.0 —
"Raise the minimum Android SDK version for Flutter from API 21 to API 26"
([#4049](https://github.com/getsentry/sentry-dart/pull/4049)); no such bump
exists in 9.x.

Consequence for HandySpeak: with minSdk 24 today, **pin `sentry_flutter:
^9.30.1`** (requires bumping the pubspec Dart floor from `3.4.0` to `3.5.0` —
harmless, the env is 3.12.2). Move to 10.x only if/when you decide the app can
require Android 8.0+.

**Privacy defaults (important for a children's app)** — per [Data Collected by
the Flutter SDK](https://docs.sentry.io/platforms/flutter/data-management/data-collected/):

- By default the SDK **does not send the user's IP address** (inferred only if
  `sendDefaultPii = true`).
- By default it **does not send the device name** (same flag).
- It **does** send runtime info (Dart version, platform) and **always** sends
  the full URL of outgoing/incoming HTTP requests (not a concern yet — the app
  makes none).

**Self-hosting escape hatch:** Sentry is [self-hostable for free]
(https://github.com/getsentry/self-hosted) under the **FSL-1.1-Apache-2.0**
license (verified from the repo's `LICENSE.md`), described as "feature-complete
and packaged up for low-volume deployments and proofs-of-concept". You'd run
Docker Compose on a small server — real ops work, but zero vendor dependency.

### 2. Firebase Crashlytics (runner-up)

- **Cost:** Crashlytics is **"No-cost"** in the Firebase pricing table
  ([firebase.google.com/pricing](https://firebase.google.com/pricing/), Crashlytics row) — effectively unlimited crash volume.
- **Android floor:** FlutterFire's `firebase_core` Android Gradle uses
  **minSdk 21 / compileSdk 34** ([source]
  (https://github.com/firebase/flutterfire/blob/master/packages/firebase_core/firebase_core/android/build.gradle))
  — comfortable headroom below the app's 24.
- **Dart floor:** latest `firebase_crashlytics` 5.4.0 wants Dart `^3.6.0`
  ([pub.dev](https://pub.dev/packages/firebase_crashlytics)) — fine for this
  env, but the pubspec floor must move to 3.6.
- **Device compatibility:** inspecting the Android SDK's POM
  (`com.google.firebase:firebase-crashlytics:21.0.0` on
  [dl.google.com maven](https://dl.google.com/dl/android/maven2/com/google/firebase/firebase-crashlytics/21.0.0/firebase-crashlytics-21.0.0.pom)),
  the only `com.google.android.gms` dependency is `play-services-tasks` — a
  small compile-time client library bundled into the APK, not the full Play
  services runtime. So it stays usable on non-GMS devices (e.g. some tablets
  common in Ukraine). `firebase-installations` (also in the POM) generates a
  device-scoped installation ID.
- **Flutter API** (verified in the published 5.4.0 sources,
  `lib/src/firebase_crashlytics.dart`): `recordFlutterFatalError` (line 160)
  for fatal crashes, `recordFlutterError` (line 141) for caught Dart errors,
  and `isCrashlyticsCollectionEnabled` (line 41) /
  `setCrashlyticsCollectionEnabled` for runtime opt-out. Usage guide:
  [get started — Flutter](https://firebase.google.com/docs/crashlytics/get-started?platform=flutter).
- **Trade-offs vs Sentry:** requires a Firebase project + `google-services.json`
  and sends crash data through Google's infrastructure; no release-health
  sessions, attachments, or free-form log levels; the dashboard is
  crash-centric. For a children's app, Google-as-processor is a heavier
  privacy story to tell than Sentry with PII off.

### 3. GlitchTip (open-source, Sentry-compatible)

[GlitchTip](https://glitchtip.com/pricing) brands itself as "open source,
Sentry API compatible error tracking" (page metadata). The hosted **Free ($0)
plan is free forever with up to 1,000 events/month**; there is a self-hosted
version (free, your infra), and hosted open-source projects start at $5/mo.

Because it speaks the Sentry API, the *same* `sentry_flutter` SDK works — you
just point the DSN at a GlitchTip server. This makes GlitchTip the natural
"leave Sentry SaaS later without rewriting code" option, or the starting point
if you already run a server and want zero third-party processors. 1k
events/month is tight but workable for a low-traffic POC. (Exact license terms
not verified — no LICENSE file at the GitHub repo root via API; check before
depending on it.)

### 4. PostHog (only if product analytics is ever wanted)

Free tier per the [pricing FAQ](https://posthog.com/pricing/): "1M events for
analytics, 5K session replays, 1M feature flag requests" monthly; the plan
cards also list **"Error tracking — 100K exceptions"** in the free column.
`posthog_flutter` 5.55.0 supports all platforms. But this is an
analytics-first platform (feature flags, replays, funnels) — for a children's
AAC app that's exactly the category of data collection you want to *avoid*
unless parents are properly informed. Keep in the back pocket; don't install
for bug-fixing alone.

### 5. Countly (self-hosted analytics)

[Countly pricing](https://countly.com/pricing): Community Edition is
"Free-forever, self-hosted, open-source product analytics"; paid editions from
**$175/month**. `countly_flutter` 26.1.1 covers Android/iOS/web. Same story as
PostHog: analytics-first; crash reporting exists but is not its center of
gravity. Not worth self-hosting just for error monitoring when GlitchTip does
that job with less surface.

### 6. Bugsnag (paid-leaning)

[Bugsnag pricing](https://www.bugsnag.com/pricing/): a Free plan exists, but
"Free tier includes **7 days of data retention**" — too short for an app whose
users report nothing and whose releases age slowly. `bugsnag_flutter` 4.2.1
(Android/iOS). Paid tiers are quote/plan-based. Doesn't earn a paid slot for
this use case.

### 7. Embrace (paid, mobile-observability focused)

[Embrace pricing](https://embrace.io/pricing/): usage-based — "$0.80 per 1,000
sessions" with a **minimum spend of $80/month** (error logs are the only free
line item). Excellent mobile UX tooling (session replay, freeze frames), but
it's a paid enterprise product; listed here for completeness since you asked
what money buys. The `embrace` pub package (4.9.0) exists and targets
iOS/Android.

### 8. Microsoft App Center — retired, avoid

App Center (the old Xamarin-era default) **retired on March 31, 2025** per the
banner on [appcenter.ms](https://appcenter.ms/) ("…retired on March 31, 2025,
except for the Analytics and Diagnostics features…"). Ignore any tutorial that
still recommends `app_center_plugin`.

## Comparison matrix

| Option | Free tier | Flutter SDK | Android floor | Kid-privacy posture | Self-host | Verdict |
|---|---|---|---|---|---|---|
| **Sentry SaaS** | 5k errors/mo | `sentry_flutter` 9.30.1 / 10.0.0 | API 21 (9.x) / **26 (10.x)** | PII off by default (no IP, no device name) | yes (FSL) | **Pick** |
| **Crashlytics** | unlimited crashes | `firebase_crashlytics` 5.4.0 | minSdk 21 | Google processor, install ID | no | Runner-up |
| **GlitchTip** | hosted 1k events/mo; self-host free | same Sentry SDK | as Sentry | your server, your rules | yes | Exit ramp |
| PostHog | 1M events, 100k exceptions | `posthog_flutter` | broad | analytics-first — heavy | yes (EE) | Later, if ever |
| Countly | CE self-host | `countly_flutter` | broad | analytics-first | yes | Pass |
| Bugsnag | free, 7-day retention | `bugsnag_flutter` | broad | standard | no | Pass |
| Embrace | none (paid) | `embrace` | broad | standard | no | Pass |
| App Center | — | — | — | — | — | Retired 2025-03-31 |

## Privacy & legal notes specific to a children's AAC app

This app is used by minors in the EU (Czech) and Ukraine, potentially US.
Telemetry must be designed so that it stays "diagnostics", not "personal data
about a child":

1. **GDPR Art. 8** ([gdpr-info.eu mirror](https://gdpr-info.eu/art-8-gdpr/),
   canonical [EUR-Lex CELEX:32016R0679](https://eur-lex.europa.eu/eli/reg/2016/679/oj)):
   offering information-society services directly to a child, consent-based
   processing is lawful from **16**; below that it needs parental consent, and
   member states may lower the threshold to 13. (Czech transposition is
   commonly cited as 15 — *unverified, confirm with counsel before relying on
   consent-based features*.) Practical takeaway: **don't build telemetry on
   consent at all** — keep it PII-free diagnostics and document it in the
   privacy policy.
2. **COPPA (US, under-13s):** the COPPA Rule lives at
   [16 CFR Part 313](https://www.ecfr.gov/current/title-16/chapter-I/subchapter-C/part-313).
   Crash/error data without individual identifiers is far easier to defend
   than behavioral analytics, but the FTC's carve-outs for internal
   troubleshooting should be reviewed before a US launch. *Flag for legal
   review, not legal advice.*
3. **Google Play Data safety form** has a dedicated **"Crash logs"**
   declaration category ([support page]
   (https://support.google.com/googleplay/android-developer/answer/10787469))
   — you'll declare that, and nothing else, if telemetry stays minimal.
4. **House rules for this codebase:**
   - Never put composer/message text, phrase-book contents, or language-set
     contents into breadcrumbs or `SentryMessage` — tag *metadata* only
     (`ui_locale`, `tts_engine_available`, `app_version`).
   - Never call Sentry's `setUser` / enable `sendDefaultPii`.
   - Disable session-replay-ish features; error events only.

## Suggested integration sketch (follows repo conventions)

- `lib/services/telemetry_service.dart` — thin wrapper around
  `SentryWidgetsFlutterBinding`/`Sentry.init` + `captureError` +
  `addBreadcrumb`; no-op when DSN absent (keeps `test/` and
  `integration_test/` hermetic — the suites in `test/support/app_harness.dart`
  stay offline).
- `lib/main.dart` — init before `runApp` (inside the existing zone/`runApp`
  chain), DSN from `--dart-define=SENTRY_DSN=…` (never committed).
- `speech_service.dart` — every TTS failure path calls
  `telemetry.captureError(e, context: 'tts/speak')`; engine-availability
  probes become a breadcrumb at startup.
- `pubspec.yaml` — `sentry_flutter: ^9.30.1`, bump Dart floor to
  `>=3.5.0 <4.0.0`.
- If adopted, record the decision as **ADR-0004** in `docs/adr/` and, when
  implemented, pair it with an ADDENDUM suite per the `handyspeak-suites`
  skill.

## Source index (fetched 2026-10-14)

- pub.dev API: `sentry_flutter` (10.0.0; sdk ≥3.12), `firebase_crashlytics`
  (5.4.0; sdk ^3.6), `posthog_flutter` (5.55.0), `countly_flutter` (26.1.1),
  `bugsnag_flutter` (4.2.1), `embrace` (4.9.0)
- https://docs.sentry.io/platforms/flutter/ — prerequisites (API 26, iOS 15)
- https://github.com/getsentry/sentry-dart/blob/main/CHANGELOG.md — API bump
  #4049 in 10.0.0 only
- https://sentry.io/pricing/ — 5k/50k errors, replay trial
- https://docs.sentry.io/platforms/flutter/data-management/data-collected/ —
  IP/device-name/runtime defaults
- https://github.com/getsentry/self-hosted — FSL-1.1-Apache-2.0, low-volume
  positioning
- https://firebase.google.com/pricing/ — Crashlytics "No-cost" row
- https://github.com/firebase/flutterfire (firebase_core android/build.gradle)
  — minSdk 21
- https://dl.google.com/…/firebase-crashlytics-21.0.0.pom — dependency list
- firebase_crashlytics 5.4.0 published sources — API names/lines
- https://glitchtip.com/pricing — free 1k events/mo, self-hosted, $5 OSS plan
- https://posthog.com/pricing — free allowances incl. 100k exceptions
- https://countly.com/pricing — CE free-forever; $175/mo paid
- https://www.bugsnag.com/pricing/ — free tier, 7-day retention
- https://embrace.io/pricing/ — $0.80/1k sessions, $80/mo minimum
- https://appcenter.ms/ — retirement banner (March 31, 2025)
- https://gdpr-info.eu/art-8-gdpr/ (+ EUR-Lex canonical) — Art. 8 ages
- https://support.google.com/googleplay/android-developer/answer/10787469 —
  Data safety "Crash logs"
- Repo/SDK: `pubspec.yaml`, `android/app/build.gradle.kts`,
  Flutter 3.44.4 `FlutterExtension.kt` (`flutter.minSdkVersion = 24`)
