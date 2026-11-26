# S02 — Implementation sequence for the R1 critical issues

- **Date:** 2026-11-26
- **Inputs:** [S01-architecture-review.md](S01-architecture-review.md) §4 (suggested sequencing), the [S02 issue analyses](S02-issue-C1.md) ([C2](S02-issue-C2.md), [C3](S02-issue-C3.md)) — in particular their verified file sets — and a parallelization assessment of those file sets.
- **Purpose:** the concrete, dependency-aware order in which the critical issues should be implemented, including what can run in parallel (git worktrees) and what must not, with the merge/integration protocol.

---

## 1. File-overlap matrix (the basis for everything below)

Derived from the verified file sets in the S02 analyses:

| | C1 (move `Phrase` to `data/`) | C2 (split settings dialog) | C3 (persistence batch) |
|---|---|---|---|
| **C1** | — | **∅ — fully disjoint** | `state/phrases_controller.dart` (both restructure it, different regions); C3's companions M5/M2 edit the `Phrase` model, which post-C1 lives in C1's new `data/phrase.dart` |
| **C2** | | — | `widgets/settings_dialog.dart` — worst kind of conflict: C2 **deletes/splits** the file while C3 **edits inside** it (`_PhrasesPane` save-failure banner) |
| **C3** | | | — |

C1 ∥ C2 disjointness holds at code level, not just file level: the dialog code never names the type `Phrase` (inference only), so none of C2's seven new files import C1's `data/phrase.dart`, and C1 touches no widget. The `export` added by C1 (see [S02-issue-C1.md](S02-issue-C1.md)) keeps every consumer compiling under either merge order.

C3 is also the only issue that adds user-visible strings (the save-failure `NoticeBanner`) → it touches `lib/l10n/app_*.arb` and regenerates the committed `app_localizations*.dart`; C1/C2 don't.

## 2. The sequence

1. **C1 — move `Phrase` to `lib/data/phrase.dart`** (with the `export` fix and the layering-guard test from [S02-issue-C1.md](S02-issue-C1.md)). Smallest critical, unlocks all later refactors; in this plan it also defines the model's home that C3's batch (M5 stable id, M2 `uses` decision) will edit.
2. **C2 — split `settings_dialog.dart`** into `lib/widgets/settings/` per [S02-issue-C2.md](S02-issue-C2.md). **Runs in parallel with C1 in its own worktree** — disjoint file sets, verified above. Optionally fold M4 (listener helper) into the same branch, per S01 §4.
3. **Merge C1, then C2** (either order works; C2 rebases onto post-C1 `main` trivially). After each merge run the local gate: `puro flutter analyze` + `puro flutter test` (the suites are the shared safety net — all three issues deliberately preserve every `ValueKey` and test contract; C2's file lists the exact suites to run).
4. **C3 + M5 + M2 — the persistence batch, after those two have merged.** Starts in its own worktree once C1 is in (it edits the moved model and rewrites `phrases_controller.dart`'s persistence path) and ideally after C2 too (its banner lands in the C2-created `settings/phrases_pane.dart`, ~5 lines). Scope, ordering rules, and the [S02 refinements](S02-issue-C3.md) — migration crash-safety (version-last, idempotent steps), write instrumentation inside `StorageService`, the controller→UI failure channel, the atomicity stance — are all in the C3 analysis. One schema-version bump absorbs all three sub-issues.
5. **Then the rest per S01 §4:** M1 (type tokens + shared shells) before the real design lands; M3, M6, M7, L1–L10 opportunistically, each independent.

> **M8 deferred (owner decision, 2026-11-26).** The CI gate is postponed for this round. Consequence: nothing checks a push or a merge automatically, so the local pre-merge runs (`puro flutter analyze` + `puro flutter test`) are the **only** gate — they are mandatory on every branch and after every merge above. Keep M8 on the backlog: it is ~30 minutes of work, S01 §4 explicitly wants it before the larger refactors, and any integration miss during this round is the signal to reconsider.

## 3. Worktree plan

```bash
# from D:\pet-projects\handy-speek
git worktree add ../handy-speek-r1c2 -b r1/c2-settings-split   # C2 — parallel with C1
# C1 is small enough to do on a short-lived branch of main directly,
# or symmetrically:
git worktree add ../handy-speek-r1c1 -b r1/c1-phrase-model
# after both merge:
git worktree add ../handy-speek-r1c3 -b r1/c3-persistence
```

Repo-specific caveats per worktree:

- **`puro flutter pub get`** in each worktree before anything runs (`.dart_tool` is per-checkout; the pub cache is shared, so it's fast).
- **Verify the puro env resolves.** Puro selects envs per project path — a fresh worktree may not auto-select `handyspeak` (the parent checkout does per CLAUDE.md). Check `puro flutter --version` and link the env if needed before blaming the code.
- **No auto-gate — M8 deferred this round.** Every branch runs `puro flutter analyze` + `puro flutter test` locally before merging; the integrator re-runs the full suite on the combined result after each merge. These local runs are the only gate (see the deferral note in §2).
- Generated l10n files are committed; if a branch regenerates them, keep the diff limited to that branch's ARB additions (only C3 adds keys).

## 4. Strict-parallel variant (only if all three must run simultaneously)

Re-scope C3 into two parts and accept one soft conflict:

- **C3a — service layer (parallel-safe):** `storage_keys.dart`, `schema_version` + migration runner, write instrumentation inside `StorageService`, `storage/write` telemetry scope, key-constant swaps in the three controllers. Shares `phrases_controller.dart` with C1 but in different regions (C1 removes lines 12–33; C3a edits `load()`/`_persist()`), so git will likely auto-merge — rebase and review manually regardless.
- **C3b — dependent tail (after C1 and C2):** corrupt-blob backup, save-failure state + `NoticeBanner` (re-applied into `settings/phrases_pane.dart`), the M5/M2 model changes riding the first real migration.

Merge order stays **C1 → C2 → C3a → C3b**; the banner is the one edit that must be manually re-applied rather than merged.

## 5. Integration checklist (whoever merges)

1. `puro flutter analyze` — zero issues.
2. `puro flutter test` — full headless suite, including the suites each S02 file pins (C2's file enumerates the dialog ones; C3's batch adds migration/round-trip tests).
3. Review the combined diff for accidental cross-touches (the overlap matrix above predicts none for C1+C2; watch `phrases_controller.dart` and `settings_dialog.dart`/`settings/phrases_pane.dart` where C3 is involved).
4. Device smoke stays a manual, per-release run (`integration_test/device_smoke_test.dart`) — unchanged by all three issues (verified: it references no dialog keys).
