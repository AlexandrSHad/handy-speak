# S3 — PR summary: issue C1, the `Phrase` model move to `lib/data/`

- **Issue:** C1 from [S01-architecture-review.md](S01-architecture-review.md) §3.1, as analyzed and amended in [S02-issue-C1.md](S02-issue-C1.md) — the `data ⇄ state` import cycle around `Phrase`.
- **Branch:** `r1/c1-phrase-model`, off `main`. (S02 §3 sketched worktrees for C2/C3 parallelism; per integrator instruction this one is a plain branch in the main checkout — C1 was explicitly "small enough" for that.)
- **Date:** 2026-11-26
- **Gate (the only one — M8/CI is deferred, S02 §2):** `puro flutter analyze` — **No issues found** · `puro flutter test` — re-run after each §5 review round: **327/327** after round one, **338/338** after round two (the guard's new parser regression suite adds 11). Device smoke is untouched by this issue (S02 verified it references no dialog keys; it imports the controller without naming `Phrase`).

## 1. What changed

| File | Change |
|---|---|
| `lib/data/phrase.dart` | **new** — `Phrase` (fields, `copyWith`, `toJson`/`fromJson`) moved **verbatim** from `phrases_controller.dart:12-33`, with its `@immutable` annotation (`package:flutter/foundation.dart show immutable` — the model's only framework need). A doc line records why the model lives below the controller. |
| `lib/data/phrases_data.dart` | `import '../state/phrases_controller.dart'` → `import 'phrase.dart'`. This deletes the codebase's **only** `data → state` edge; the import graph is one-way everywhere now. |
| `lib/state/phrases_controller.dart` | Model class removed; imports `../data/phrase.dart` (one-way) **and** re-exports it — see §2. Controller logic untouched. |
| `lib/data/symbol_categories.dart` | `import 'package:flutter/material.dart'` (pulled in only for `Color`) → `import 'dart:ui' show Color`. The L2 sibling fix S01 folded into C1's pass. Scope note (PR #13 review): this drops the layer's **only direct Material import** — it does not make the layer framework-free; `phrase.dart` still uses `@immutable` from `flutter/foundation.dart`, and every data file transitively sees `flutter/widgets.dart` through `core/app_language.dart` (`Locale`). `package:meta` would make the model file pure Dart, but `meta` is not a declared dependency, so the claim was softened wherever it lived instead. |
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

`test/unit/data/layering_test.dart` walks every `lib/data/**/*.dart` — recursively, so a future subdirectory cannot slip past the check — and fails if any **import or export** directive resolves into `lib/state/`: both directive kinds (an export of state from data is the same violation) and both forms, relative (`../state/…`, resolved from the importing file's own directory) and package (`package:handy_speak/state/…`). The scan blanks comments first, string-aware (a `//` inside a phrase string is not a comment), so a comment can neither *hide* a directive that follows it — the bug the re-review caught in the first statement-split version — nor *smuggle* a fake violation into a fragment; the cleaned source is then split on `;` into statements, not lines, so a directive split across lines, a line packing several directives, either quote style, and every URI of a conditional import/export are all covered. Only directive URIs are ever parsed, never free text; a non-vacuity check (the directory exists and holds Dart files) makes a silently-empty guard fail loudly; and the parser is a pure function whose edge cases are pinned by their own regression suite. It runs on every platform via `puro flutter test` — S02's preference over S01's POSIX-only CI `grep -r "state/" lib/data/`, which isn't guaranteed on this repo's Windows dev machines and false-positives on comments.

## 4. Merge notes (for the integrator, per S02 §5)

1. Merge `r1/c1-phrase-model` into `main`, then re-run `puro flutter analyze` + `puro flutter test` on the combined result.
2. No overlap with C2 (verified disjoint in S02 §1) — C2 can start or rebase immediately after this lands.
3. C3 + M5 + M2 (the persistence batch) now have the model's home: their `Phrase` edits (stable id, the `uses` decision) belong in `lib/data/phrase.dart`, absorbed by the first schema-version bump (S02 §2 step 4).

## 5. PR #13 review follow-ups

Two review rounds (three comments, all nits) were addressed on the branch after the first push — round one was the two nits below; round two caught a regression in the round-one guard fix (item 3):

1. **"Data layer no longer drags Material" was overstated.** Correct: `phrase.dart` still imports `flutter/foundation.dart` for `@immutable`, and every data file transitively sees `flutter/widgets.dart` through `core/app_language.dart` (`Locale`). Fix: the claim was softened to "the layer's only direct *Material* import is gone" everywhere it lived — §1 above, the `symbol_categories.dart` header, the `phrase.dart` doc comment, and this PR's description. The `package:meta` option was considered and declined: `meta` is in the lock file only as a *transitive* dependency, and declaring a new one to remove a single annotation would widen what is otherwise a pure move — the decision is recorded in `phrase.dart`'s doc comment, where a future framework-free pass can find it.
2. **Layering-guard blind spots.** The guard matched only single-quoted URIs, parsed directives line-at-a-time (so `import` / newline / `'…'` escaped), and listed `lib/data` non-recursively (subdirectories would escape). Fix: statement-level parsing (both quote styles, multi-line directives, several directives per line, every conditional-URI), a recursive walk, and relative URIs resolved from each file's own directory — see §3.
3. **The statement split hid directives behind comments (re-review).** The round-2 fix split the source on `;` and required each fragment to *start* with the `import`/`export` keyword — but a fragment carries everything since the previous `;`, so any comment before a directive swallowed it: `import 'a.dart';` / `// note` / `import '../state/x.dart';` went unreported, and a file opening with a comment header (like `symbol_categories.dart`) had its first directive invisible. A regression against the original line-based guard, which caught directives after comments. Fix: comments are blanked before the split — string-aware, so a `//` inside a phrase string is not a comment — which also closes the inverse hazard the split itself introduced (a comment *describing* a state import, once cut by its own `;`, could smuggle a fake violation into a fragment). The parser became a pure function with its own regression suite covering both review rounds' cases — see §3.
