# S02 — Deep analysis of issue C1: the `Phrase` model creates a `data ⇄ state` import cycle

- **Source issue:** [S01-architecture-review.md](S01-architecture-review.md) §3.1, C1
- **Analysis date:** 2026-11-25
- **Method:** every factual claim re-verified against the current code (full file reads + import-graph greps over `lib/` and `test/`); assessment cross-checked against official Flutter architecture guidance and Dart import semantics.
- **Verdict:** **AGREED — the issue is valid, the reasoning is correct, and the proposed solution works.** One genuinely important detail was missed: as written, the move **breaks the compilation of an existing test suite**, which the review predicted would not happen. Stored below with that one-line fix and a portability tweak to the guard. No other changes.

---

## 1. Fact verification

| # | Review claim | Result | Evidence (current code) |
|---|---|---|---|
| 1 | `state/phrases_controller.dart:7` imports `data/phrases_data.dart` | ✅ exact | `phrases_controller.dart:7` |
| 2 | `data/phrases_data.dart:2` imports `state/phrases_controller.dart` | ✅ exact | `phrases_data.dart:2` |
| 3 | `Phrase` class + JSON codec declared at `phrases_controller.dart:12-33` | ✅ exact | lines 12–33 (`@immutable class Phrase`, `copyWith`, `toJson`, `fromJson`) |
| 4 | Seeds live at `phrases_data.dart:7-37` | ✅ | lines 7–38 (`kSeedPhrases`, 8 phrases × 3 languages) |
| 5 | This pair is the **only** `data → state` edge in the codebase | ✅ | grep of `^import` across all four `lib/data/` files: only `phrases_data.dart` references `state/`; the other three import only `core/` (+ Material in `symbol_categories`) |
| 6 | `data/symbol_categories.dart:1` imports Flutter Material only for `Color` | ✅ | line 1; `Color` is used solely for the 8 decorative category hues |
| 7 | Widget consumers read `Phrase` through the controller import | ✅ | `phrase_strip.dart:10`, `settings_dialog.dart:10`, plus `main.dart:17` |

Every checkable fact — including all line numbers — is accurate.

## 2. Reasoning assessment — correct

1. **"Any future consumer of `Phrase` … must import the controller file and drag `ChangeNotifier`, `StorageService`, `TelemetryService`."** Verified: `phrases_controller.dart` imports `package:flutter/foundation.dart` (ChangeNotifier), `services/storage_service.dart`, and `services/telemetry_service.dart`. A phrase search, export/backup, or repository seam built on `Phrase` today transitively depends on all three. The review's core maintainability argument stands.
2. **"Dart compiles import cycles, so nothing will ever stop this from growing."** Correct. Dart's compiler and analyzer accept intra-package import cycles without any diagnostic — community consensus is that intra-package cycles are *legal*; whether they are *acceptable is purely an architectural judgment*. That is exactly why the review's third point (the project's own documented convention is contradicted by its own files, and contributors copying the local pattern will create further cycles) is the strongest of the three: the only thing the cycle costs today is the layering rule itself, and the only guard against growth is discipline or tooling, neither of which exists.
3. **Severity: Critical.** Fair under the review's own definition ("breaks a structural rule"). The structural rule — `data/` never imports `state/`, per CLAUDE.md's layout convention — is broken in exactly one place, verified. A nuance worth recording honestly: the cycle causes no compile-time, runtime, or performance harm; the entire cost is future-change cost. Under this review's maintainability lens that is still Critical, because the file pair in question is the persistence path for the app's most valuable data and is on every roadmap (per C3/M2/M5).

**External grounding.** Flutter's official architecture guidance makes separation of concerns the primary principle, with a one-way dependency from the UI layer down to the data layer — the proposed end-state (`data/` imports only `core/`) restores exactly that shape for the last violating pair. Go's "no circular imports by design" and Python/JS communities' workarounds all point the same direction: the shared, depended-on type belongs in the lower layer.

## 3. Solution assessment — works, with one missed detail

The proposed mechanical move (class + codec → `lib/data/phrase.dart`; `phrases_data.dart` imports it; the controller imports both) is correct: no behavior change, layering restored, direction one-way, effort genuinely hour-level.

### The missed detail: "existing suites should pass unchanged" is false as stated

- The review's correctness argument is: *"imports in `phrases_controller.dart`, `phrases_data.dart`, and the two widget consumers stay valid (widgets already import the controller and read `Phrase` through it)."*
- For `lib/` the conclusion holds — but for a **subtler reason than the one given**. `phrase_strip.dart` and `settings_dialog.dart` never *name* the type `Phrase` (verified: both touch phrases only via `phrasesFor()` results bound to inferred locals), and Dart's type inference does not require importing the library that declares the type. "Reading `Phrase` through the controller" is not a real Dart mechanism — **imports are non-transitive**; importing a library exposes its own declarations, not those of its imports.
- The consequence surfaces exactly where the review did not look: **`test/unit/state/phrases_controller_test.dart` imports only `package:handy_speak/state/phrases_controller.dart` and names `Phrase(...)` as a type in 20+ places.** After a bare move, `Phrase` is no longer in scope through that import and the suite **stops compiling** — the opposite of the review's "existing suites should pass unchanged since public names are identical." Identical public names do not help when the name resolves through a different library.
- **One-line fix:** have `phrases_controller.dart` re-export the moved model — `export '../data/phrase.dart';`. This (a) makes the review's "widgets read `Phrase` through the controller" reasoning actually true, (b) keeps every current consumer — lib *and* test — compiling with zero import edits, and (c) preserves the controller as the historical import surface while new consumers (`data`/`services`/future repositories) import `data/phrase.dart` directly and stay decoupled from the controller, which is the point of the whole exercise.

### Secondary refinement: the layering guard should be a test, not a shell grep

The suggested guard — `grep -r "state/" lib/data/` must be empty — works on POSIX CI, but plain `grep` is not guaranteed on the Windows machines this repo is developed on (CLAUDE.md runs everything through Puro), and a comment mentioning `state/` would false-positive. The repo already has a better home for the check: a small unit test (e.g. `test/unit/data/layering_test.dart`) that reads every `lib/data/*.dart` file and asserts no import path resolves into `../state/`. It runs on all platforms via `puro flutter test`, fits the existing suite shape (`test/unit/data/` already exists), and is picked up automatically by the CI gate proposed in M8 — closing the loop the review itself describes ("the analyzer cannot warn about layering").

Everything else in the proposal — the location choice (`lib/data/` is importable by `state/` and matches the CLAUDE.md vocabulary; `core/` would be equally valid but data/ is the smaller conceptual change), folding the `symbol_categories.dart` `Color` fix into the same pass, and the effort/risk estimate — is sound.

---

## 4. Stored issue (C1) — with minimal S02 changes

> Changes vs. S01 are marked **[S02]**; everything else is unchanged in substance.

#### C1. The `Phrase` model creates a `data ⇄ state` import cycle — the layering rule is broken in exactly one place

**Facts.**

- `lib/state/phrases_controller.dart:7` imports `../data/phrases_data.dart` (controller seeds from `kSeedPhrases`).
- `lib/data/phrases_data.dart:2` imports `../state/phrases_controller.dart` (seed data constructs `Phrase` objects).
- The `Phrase` class — the domain model *and* its JSON codec — is declared inside the controller file (`phrases_controller.dart:12-33`); the static seed content lives in the data file (`phrases_data.dart:7-37`). Each file imports the other. Dart compiles import cycles, so nothing will ever stop this from growing.

**Current dependency shape:**

```
widgets/phrase_strip.dart ─────────┐
widgets/settings_dialog.dart ──┐   │
                               ▼   ▼
                  state/phrases_controller.dart
                  (declares class Phrase +
                   JSON codec + ChangeNotifier)
                        │              ▲
              imports ▼               │ imports   ← CYCLE
              data/phrases_data.dart ─┘
              (kSeedPhrases: List<Phrase>)
```

Every other pair in the codebase follows the rule drawn in §2.1 (`data` never imports `state`). A smaller sibling of the same smell: `data/symbol_categories.dart:1` imports `package:flutter/material.dart` only for `Color`, tying the data layer to the Flutter framework.

**Why it matters for the future.**

1. The class carries three responsibilities at once: domain model, persistence codec (`toJson`/`fromJson`), and seed-data value type. Any future consumer of `Phrase` — phrase search, export/backup, per-phrase settings, a `PhrasesRepository` seam — must import the **controller** file and therefore drag `ChangeNotifier`, `StorageService`, and `TelemetryService` into its dependency graph.
2. Extracting a `state/` package, splitting persistence from controllers, or building a repository seam (all plausible next steps once the POC grows) each start by breaking this cycle; until then, every refactor of either file drags the other.
3. The codebase's own convention (`CLAUDE.md`: static content in `lib/data/`, controllers in `lib/state/`) is contradicted by its own files. New contributors (or agents) copying the local pattern will create further cycles, because the analyzer cannot warn about layering.

**Decisions that led here.** `Phrase` was declared in the controller following the implementation plan's task split ("A quick phrase belonging to one language (IMPLEMENTATION_PLAN §6)", `phrases_controller.dart:11`); seeds went to `lib/data/` per the layout convention ("static content: … phrases_data" — `CLAUDE.md`). The two files then grew toward each other and nobody moved the class.

**What makes sense to add.**

- Move `Phrase` (class + codec) into `lib/data/` — either into `phrases_data.dart` itself, or a new `lib/data/phrase.dart`:

```
lib/data/
  phrase.dart          ← class Phrase { text, pinned, uses } + toJson/fromJson
  phrases_data.dart    ← kSeedPhrases (imports phrase.dart, imports NOTHING from state/)
  pictograms.dart
  symbol_categories.dart
  keyboard_layouts.dart
lib/state/
  phrases_controller.dart  ← imports ../data/phrase.dart + ../data/phrases_data.dart (one-way)
                           + [S02] export '../data/phrase.dart';
```

- This is a mechanical move: no behavior change, imports in `phrases_controller.dart`, `phrases_data.dart`, and the two widget consumers stay valid (widgets already import the controller and read `Phrase` through it **[S02: via type inference today; the export below makes this literally true and keeps `test/unit/state/phrases_controller_test.dart` — which names `Phrase` 20+ times through the controller import — compiling unchanged. Dart imports are non-transitive: without the `export`, that suite stops compiling and "existing suites pass unchanged" is false.]**).
- To keep the rule from regressing: add a layering check that does not touch `test/` — **[S02: prefer a small unit test, e.g. `test/unit/data/layering_test.dart`, that walks `lib/data/*.dart` and asserts no import resolves into `../state/` — it runs everywhere via `puro flutter test`, fits the repo's suite conventions, and is enforced by the CI gate proposed in M8. A CI `grep -r "state/" lib/data/` also works on POSIX runners, but is not guaranteed on this repo's Windows dev machines and false-positives on comments.]** The `symbol_categories.dart` Material import can be fixed in the same pass (use `dart:ui`'s `Color`, or move category colors to `AppTokens`).
- **Effort:** small (an hour-level change). **Risk:** low (pure move; existing suites should pass unchanged since public names are identical **[S02: provided the `export` line is added — see above]**). Good first pick.
