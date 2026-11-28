# Persisted storage is one versioned schema with data-safe failure handling

Every byte this app persists — the language set, the per-language phrase
lists, the eight settings booleans — is **one schema**, owned by
`lib/services/storage_keys.dart`: the key constants, `kSchemaVersion`
(currently 2), the pure migration steps, and the runner. A new persisted
key joins that module and bumps the version with a migration step;
controllers own no key string literals and no upgrade logic.
`StorageService.init()` runs the migrations before it returns, so no
controller's `load()` can ever see pre-migration data.

The migration protocol is crash-safe by construction, not by hope:
`shared_preferences` has no transaction, and a process death mid-migration
must not leave a half-migrated store. Every step is **pure and
idempotent** (a re-run converges instead of corrupting), `schema_version`
is written **only after all steps have succeeded** (version-last), and the
runner refuses to run over a store written by a newer build. An
interrupted migration therefore re-runs cleanly on the next boot.

The atomicity stance is recorded: multi-key writes stay multi-key, and
correctness comes from **load-time repair** — the language set's Q17
snap-back already repairs a partially-written store at load. The
alternative, folding `main_lang` + `second_lang` into a single
`language_set` JSON key so the invariant becomes one write, is
deliberately deferred as the candidate *first future migration*, not
slipped into this one.

The app's only irreplaceable data is parent-entered phrases, and the
failure paths around it are load-bearing policy:

- **Corrupt blob → backup before the destructive fallback.** A phrase
  blob that fails to decode is copied to `phrases_{lang}.corrupt` (one
  self-capping slot per language), and the original key is removed
  **only after the backup write succeeds**. A failed backup leaves the
  original key in place.
- **A failed backup quarantines the language for the session.** The
  in-memory list re-seeds so the child keeps a working surface, but
  `_persist` refuses to write that language: a re-seeded list must never
  overwrite the last surviving copy of the parent's content. The Phrases
  pane shows the save-failure banner; the next boot retries the backup.
  **Do not "fix" the persist-block — it is the guard.** Session edits are
  the sacrifice, and that is the decision.
- **Writes are observable at the seam.** `StorageService` wraps
  `setString`/`setBool`/`remove` in one place; a failure is captured
  under the `storage/write` telemetry scope with the **key name only,
  never the value** (ADR-0004's content-free stance), then re-thrown so
  awaiting callers can drive the in-app banner.

Schema v2 — the first versioned bump; a store with no `schema_version`
key is v1 — carried three riders so they cost one bump instead of three:
`Phrase` gained a **stable per-list int id** (remove/togglePin address
exactly one row, not every same-text row; identity is immutable, which is
why `copyWith` has no `id` parameter), the never-incremented `uses`
counter was **removed entirely** (owner decision 2026-11-28: fabricated
statistics presented as real; if usage counting returns, it arrives with
its own migration step), and the debug-only round-trip check of the
phrase write rode along.

Considered and rejected: instrumenting the 11+ write call sites instead
of the service seam (one wrapper catches every current and future
writer); a version-first marker (crash-unsafe — an interrupted migration
would look complete); retrying the quarantine backup mid-session with
state (the safe direction is the next boot, which re-reports and
retries).

Analysis: `docs/continuous-improvement/R1-architecture/S02-issue-C3.md`.
Implementation: PR #15,
`docs/continuous-improvement/R1-architecture/S3-issue-C3-pr-summary.md`.
