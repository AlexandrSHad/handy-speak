# S3 — PR summary: issue C1, the `Phrase` model move to `lib/data/`

- **Issue:** C1 from [S01-architecture-review.md](S01-architecture-review.md) §3.1, as analyzed and amended in [S02-issue-C1.md](S02-issue-C1.md) — the `data ⇄ state` import cycle around `Phrase`.
- **Branch:** `r1/c1-phrase-model`, off `main`. (S02 §3 sketched worktrees for C2/C3 parallelism; per integrator instruction this one is a plain branch in the main checkout — C1 was explicitly "small enough" for that.)
- **Date:** 2026-11-26
- **Gate (the only one — M8/CI is deferred, S02 §2):** `puro flutter analyze` — **No issues found** · `puro flutter test` — **327/327 passed** (was 325; the new layering suite adds 2). Device smoke is untouched by this issue (S02 verified it references no dialog keys; it imports the controller without naming `Phrase`).

## 1. What changed

| File | Change |
|---|---|
| `lib/data/phrase.dart` | **new** — `Phrase` (fields, `copyWith`, `toJson`/`fromJson`) moved **verbatim** from `phrases_controller.dart:12-33`, with its `@immutable` annotation (`package:flutter/foundation.dart show immutable` — the model's only framework need). A doc line records why the model lives below the controller. |
| `lib/data/phrases_data.dart` | `import '../state/phrases_controller.dart'` → `import 'phrase.dart'`. This deletes the codebase's **only** `data → state` edge; the import graph is one-way everywhere now. |
| `lib/state/phrases_controller.dart` | Model class removed; imports `../data/phrase.dart` (one-way) **and** re-exports it — see §2. Controller logic untouched. |
| `lib/data/symbol_categories.dart` | `import 'package:flutter/material.dart'` (pulled in only for `Color`) → `import 'dart:ui' show Color`. The L2 sibling fix S01 folded into C1's pass: the data layer no longer drags Material. |
| `test/unit/data/layering_test.dart` | **new** — the regression guard, see §3. |

No pubspec, l10n/ARB, or generated-file changes. No behavior change: a pure move plus two import swaps.

## 2. The re-export shim (the S02 fix)

`phrases_controller.dart` closes its import block with:

```dart
export '../data/phrase.dart';
```

Dart imports are non-transitive, so a bare move would have broken `test/unit/state/phrases_controller_test.dart`, which names `Phrase` 20+ times through the controller import — the one detail S01's "existing suites pass unchanged" prediction missed (S02-issue-C1 §3). The export keeps every existing consumer compiling with **zero import edits**: the two widget consumers (`phrase_strip.dart`, `settings_dialog.dart`) never name the type (inference only), and `main.dart`, `app_harness.dart`, the behavior suites, and the device smoke import the controller as before.

New consumers should import `package:handy_speak/data/phrase.dart` directly — that decoupling is the point of C1; the controller stays the historical import surface.

The `import` + `export` pair on one URI is the canonical "use and re-export" pattern (Flutter SDK does it in `src/physics/simulation.dart`, `src/gestures/team.dart`, `src/services/autofill.dart`), and `unnecessary_import` fires only when the used names are covered by another *import* (dart.dev/tools/diagnostics/unnecessary_import) — confirmed by the clean analyze gate.

## 3. The layering guard

`test/unit/data/layering_test.dart` walks every `lib/data/*.dart` and fails if any **import or export** directive resolves into `lib/state/` — covering both the relative (`../state/…`) and package (`package:handy_speak/state/…`) forms, and both directive kinds (an export of state from data is the same violation). It parses directive URIs only, never free text, so a comment that merely mentions `state/` cannot false-positive; a non-vacuity check (the directory exists and holds Dart files) makes a silently-empty guard fail loudly. It runs on every platform via `puro flutter test` — S02's preference over S01's POSIX-only CI `grep -r "state/" lib/data/`, which isn't guaranteed on this repo's Windows dev machines and false-positives on comments.

## 4. Merge notes (for the integrator, per S02 §5)

1. Merge `r1/c1-phrase-model` into `main`, then re-run `puro flutter analyze` + `puro flutter test` on the combined result.
2. No overlap with C2 (verified disjoint in S02 §1) — C2 can start or rebase immediately after this lands.
3. C3 + M5 + M2 (the persistence batch) now have the model's home: their `Phrase` edits (stable id, the `uses` decision) belong in `lib/data/phrase.dart`, absorbed by the first schema-version bump (S02 §2 step 4).
