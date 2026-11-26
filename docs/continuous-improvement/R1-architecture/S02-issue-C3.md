# S02 — Deep analysis of issue C3: persistence has no schema versioning, performs non-atomic multi-key writes, and fails silently

- **Source issue:** [S01-architecture-review.md](S01-architecture-review.md) §3.1, C3
- **Analysis date:** 2026-11-25
- **Method:** all three controllers, the storage service, `main.dart`, and the telemetry scope policy read in full; every write path and failure path traced; the `uses` field grep-verified for mutation sites; assessment cross-checked against Android `SharedPreferences` write semantics and Flutter persistence guidance.
- **Verdict:** **AGREED — the issue is valid, Critical severity is justified, and the reasoning is correct.** The proposed solution is right in direction; all five items are endorsed. Three points were under-specified or unstated and matter enough to record (migration crash-safety, where write instrumentation lives, and the in-app-notice channel), plus one stance the issue leaves implicit (multi-key atomicity). Stored below with those minimal, clearly-marked additions — no item of the original proposal is rejected.

---

## 1. Fact verification

| # | Review claim | Result | Evidence (current code) |
|---|---|---|---|
| 1a | `LanguageController` keys at `language_controller.dart:36-38` | ✅ | `active_lang`, `main_lang`, `second_lang` |
| 1b | `PhrasesController` key at `phrases_controller.dart:46` | ✅ | `phrases_${l.key}` → `phrases_en` / `phrases_cs` / `phrases_uk` (JSON blobs) |
| 1c | `SettingsController`: 8 boolean keys at `settings_controller.dart:13-20` | ✅ | `dark_mode`, `haptics`, `big_letters`, `show_phrases`, `speak_letters`, `speak_words`, `speak_symbols`, `speak_phrases` |
| 1d | No registry, no schema version anywhere | ✅ | key literals live in three controllers; `StorageService` (24 lines) has no version concept |
| 2 | `_persistPair()` issues 2–3 independent writes | ✅ | `language_controller.dart:182-190` (setString + remove/setString); the first-run path in `load()` additionally writes `_kActiveLang` separately (83–84) |
| 2b | The code itself documents the partial-store hazard (Q17) | ✅ | `language_controller.dart:89-93` — quote verified verbatim; the snap-back at line 93 implements the repair |
| 3 | All writes fire-and-forget | ✅ | all 8 `SettingsController` setters (64–110) discard the `setBool` future; `_persist` (`phrases_controller.dart:111-114`) discards `setString`'s future (not even `unawaited` — that import is used only for telemetry); `_persistPair` and `setLanguage` (118) likewise |
| 3b | Allowlist covers `storage/init` only; no `storage/write` scope | ✅ | `telemetry_service.dart:281-291`: scope set = {framework/render, platform, storage/init, tts/init, tts/set_language, tts/voices, tts/speak, tts/stop, phrases/load_corrupt} |
| 4 | Corrupt phrase JSON → silent seed overwrite | ✅ | catch at `phrases_controller.dart:59-71` → seeds; telemetry is content-free by construction (`phrases/load_corrupt` is in `_suppressMessageScopes`, `telemetry_service.dart:276` — the raw exception message is replaced, tags carry only `phrases_lang` + `raw_length`); no in-app notice; the corrupt blob is overwritten by the next `_persist` (111–114 — `_byLang` now holds seeds, so any add/remove/togglePin rewrites the key) |
| 5 | `uses` is persisted, displayed, sorted — but never incremented | ✅ | grep over `lib/`: zero mutation sites; seeds fabricate 42/31/28… (`phrases_data.dart`); displayed at `settings_dialog.dart:1033`; sorted at `phrases_controller.dart:81` |
| — | `StorageService.init()` failure instrumented then rethrown | ✅ | `main.dart:46-53`, scope `storage/init` |

Every factual claim in C3 is accurate, including line numbers and the telemetry-policy details.

## 2. Reasoning assessment — correct

1. **"This app's most valuable data is parent-entered child-specific content."** Correct, and the load-bearing word is *irreplaceable*: phrase lists are the only user-authored persisted data; everything else is re-derivable preferences.
2. **The roadmap pressure argument.** Verified: mood voices are POC-deferred but planned (`settings_controller.dart:5-7` documents the disabled row; `settings_dialog.dart:863-884` renders it); real usage counters are M2; phrase identity is M5; export/backup is proposed here — all four extend the persisted schema.
3. **"No mechanism to distinguish first run from data lost."** Verified: `load()` treats an absent `main_lang` as first-run (74–84) and would treat a data-losing schema change identically — the failure mode is structural, not hypothetical.
4. **Platform behavior confirms the silent-failure claim.** Android `SharedPreferences` persists writes asynchronously; write failures are not surfaced to the caller (apply semantics — documented behavior and long-standing community observation, e.g. "apply() saves asynchronously and fails silently"). Even in the Flutter case where the plugin future *does* reject, this app discards it — at best it surfaces as an unhandled zone error captured under the generic `platform` scope, with no indication of which key failed, which is precisely what the review states ("surfaces — if at all — as a generic unhandled platform error").
5. **Severity: Critical — justified.** The corrupt-JSON path silently destroys the only irreplaceable data, unrecoverably (no backup, overwritten on next mutation, parent never told). Under any lens that weighs data risk, this is Critical; the review's own severity definition explicitly includes "risks data."

## 3. Solution assessment — agree with all five items, with three recorded refinements

**Item 1 — single storage schema module.** Endorsed. Centralizing key constants plus a `schemaVersion` constant is hour-level work, makes the whole persisted schema visible in one file, and is the prerequisite for item 2.

**Item 2 — versioned load-time migration.** Endorsed, with one important omission:

- **[S02 addition — migration crash-safety.]** A migration is itself a multi-key write over the very store that has no transactionality (the issue's own fact 2). A process death mid-migration would leave a half-migrated store — a *new* silent-corruption path of exactly the kind the framework exists to remove. Two rules close it: **write `schema_version` only after all migration steps have succeeded** (version-last), and **make every step idempotent** (a re-run on next boot after an interrupted migration converges rather than corrupts). Also: run migrations in `init()` *before* any controller's `load()` — the review says "before controllers see data," which is right and should be pinned as an ordering rule, not an assumption.

**Item 3 — observable writes.** Endorsed, with two under-specifications:

- **[S02 addition — where instrumentation lives.]** Do not instrument the 11+ call sites (8 settings setters, `_persist`, `_persistPair`, `setLanguage`, first-run writes). Wrap `setString` / `setBool` / `remove` inside `StorageService` itself and route failures to the new `storage/write` scope (tags = key name only, never values). One place catches every current and future writer, and the seam stays in-layer: `StorageService` currently imports nothing app-internal, and `TelemetryService` is a same-layer (`services/`) dependency; `main.dart` already constructs telemetry before storage (`main.dart:30, 45`), so the wiring is a one-parameter change. This is the same "one adapter owns the plugin" discipline the review praises in §2.1.
- **[S02 addition — the in-app notice needs a channel that doesn't exist yet.]** "Surface an in-app `NoticeBanner`" requires a controller→UI error path; today errors go to telemetry only. The smallest design that fits the existing patterns: `PhrasesController` exposes a transient save-failure state (set in `_persist`'s failure path, cleared on the next successful persist) and notifies; `_PhrasesPane` already watches `PhrasesController` (`settings_dialog.dart:965`) and `NoticeBanner` already exists and is used inside this very dialog (`notice_banner.dart`, used at 703/714/738). No new architecture — one field plus one conditional widget.

**Item 4 — backup before destructive fallback.** Endorsed as-is. The `.corrupt` rename is one extra `setString`, it is self-capping (the write overwrites the single `.corrupt` slot per language — it cannot grow unboundedly), and the quarantined content stays on-device, which keeps ADR-0004's content-free telemetry stance intact (nothing is shipped; the event still reports only type + length). 

**Item 5 — debug round-trip verification.** Endorsed as optional; harmless in debug builds.

**[S02 addition — the atomicity stance the issue leaves implicit.]** Fact 2 documents non-atomic multi-key writes, but no fix item addresses them. Be explicit: `shared_preferences` has **no multi-key transaction**, so the honest options are (a) keep multi-key writes and rely on load-time repair — already implemented and adequate for the language set (the Q17 snap-back, `language_controller.dart:89-93`) — or (b) when the first schema migration lands anyway, collapse `main_lang` + `second_lang` into a single `language_set` JSON key so the invariant becomes one write. Pick one and record it; (a) is acceptable today, and (b) falls out of the migration work nearly for free. What should *not* happen is leaving the stance undecided so each future feature re-guesses.

**Sequencing note.** The review's §4 batches C3 + M5 + M2 as one persistence-themed change. That is right: the schema migration (item 2) is the natural moment to give `Phrase` a stable id (M5) and to either wire or drop `uses` (M2) — one version bump, one migration, one set of round-trip tests, instead of three.

---

## 4. Stored issue (C3) — with minimal S02 changes

> Changes vs. S01 are marked **[S02]**; everything else is unchanged in substance. No original item is rejected; the additions make items 2 and 3 safe/complete and record the atomicity stance.

#### C3. Persistence has no schema versioning, performs non-atomic multi-key writes, and fails silently

**Facts.**

1. **Keys are defined ad-hoc in three controllers, with no registry and no version:**
   - `LanguageController` (`language_controller.dart:36-38`): `active_lang`, `main_lang`, `second_lang`;
   - `PhrasesController` (`phrases_controller.dart:46`): `phrases_en`, `phrases_cs`, `phrases_uk` (JSON blobs);
   - `SettingsController` (`settings_controller.dart:13-20`): 8 boolean keys.
   Nothing records that these keys form one schema, or which version of the app wrote them.
2. **Multi-key writes are non-atomic.** `_persistPair()` issues two or three independent writes (`language_controller.dart:182-190`). The code itself documents the consequence: *"a corrupted or partially-written store could restore an active language outside the set — snap it back rather than leaving it dangling (Q17)"* (`language_controller.dart:89-93`). A process death or a write failure mid-sequence leaves a half-applied state that `load()` must defensively repair.
3. **All writes are fire-and-forget.** Every `setBool`/`setString`/`remove` future is ignored at the call site (all 8 `SettingsController` setters, `_persistPair`, `_persist` in `phrases_controller.dart:111-114`). A failed write surfaces — if at all — as a generic unhandled platform error after the fact, with no indication *which* key failed and nothing in the UI. The telemetry scope allowlist covers `storage/init` only; there is no `storage/write` scope.
4. **Corrupt phrase JSON silently destroys parent-entered content.** On a decode failure the controller replaces the stored list with seed phrases (`phrases_controller.dart:59-71`). The only signals are a deliberately content-free telemetry event and `raw_length`. The parent is never told in-app; the old blob is overwritten on the next `_persist`, so recovery is impossible.
5. **The stored schema already carries dead weight:** `uses` is persisted, displayed ("42× used"), and used for sorting, but no code path ever increments it (see M2) — a field whose only values are fabricated seed numbers.

**Current shape:**

```
LanguageController        PhrasesController        SettingsController
  main_lang / second_lang   phrases_{en,cs,uk}       8 bool keys
  active_lang               (JSON blobs)
        │                        │                        │
        └──────── fire-and-forget setString/setBool ──────┘
                               SharedPreferences
              (no schema_version key · no write-error
               handling · no backup before destructive
               fallback · corrupt JSON ⇒ seed overwrite)
```

**Why it matters for the future.**

This app's most valuable data is **parent-entered child-specific content** (phrase lists). Everything on the visible roadmap needs persistence schema changes: mood voices (per-child voice settings, §2), real usage counters (M2), phrase editing/reordering, per-language settings, export/backup. Today each of those would land as *more ad-hoc keys with no upgrade path*: an old install either keeps stale keys forever or silently reads fallbacks — and there is no mechanism to distinguish "first run" from "data lost to a schema change", which is exactly the failure mode the language-set code already has to defend against (Q17).

**Decisions that led here.** The POC deliberately used the thinnest possible persistence (shared_preferences, sync-after-init reads, write-and-forget — `IMPLEMENTATION_PLAN §5`); ADR-0004 deliberately made telemetry content-free (which limits recovery diagnostics to type + length); Q5 chose "absent key = none" encoding, which is fine but adds to the set of invariants each controller must know individually.

**What makes sense to add.**

1. **A single storage schema module** — e.g. `lib/services/storage_keys.dart` (or a `PhrasesStore`/`SettingsStore` repository seam per feature): every key constant in one file, plus `schemaVersion` int written once. Controllers keep their behavior; they just stop owning string literals.
2. **Versioned load-time migration:** on `init()`, read `schema_version`; run ordered, pure migration steps (`String? migrateV1toV2(String raw)`) before controllers see data. Corrupt-blob handling becomes one place, not a per-controller `try/catch`. **[S02: migration crash-safety — write `schema_version` only after all steps succeed, and make every step idempotent, so a process death mid-migration re-runs cleanly on next boot instead of leaving a half-migrated store; run migrations in `init()` before any controller's `load()`.]**
3. **Observable writes:** route write failures through the existing telemetry seam (add a `storage/write` scope to the allowlist, tags = key name only, never values), and for phrase saves specifically surface an in-app `NoticeBanner` — silent loss of a parent's phrases is the worst failure this app can have. **[S02: instrument inside `StorageService` (wrap `setString`/`setBool`/`remove`, one place, in-layer `TelemetryService` dependency; `main.dart` already builds telemetry before storage) rather than at the 11+ call sites; the banner channel: `PhrasesController` exposes a transient save-failure state and notifies — `_PhrasesPane` already watches the controller, and `NoticeBanner` is already used in that dialog.]**
4. **Backup before destructive fallback:** when phrases JSON fails to decode, rename the blob to `phrases_{lang}.corrupt` before re-seeding, so a support path can recover it. One extra `setString`. **[S02: self-capping — the rename overwrites the single `.corrupt` slot per language; quarantined content stays on-device, consistent with ADR-0004.]**
5. Optionally, `debugPrint`-level round-trip verification of critical writes in debug builds.

**[S02: atomicity stance (record it, don't leave it implicit):]** `shared_preferences` has no multi-key transaction. Either (a) keep multi-key writes and rely on the existing Q17 load-time snap-back (already implemented, adequate for the language set), or (b) fold `main_lang`+`second_lang` into one `language_set` JSON key as the first schema migration, making the invariant a single write. (a) is acceptable today; (b) is nearly free once item 2 exists.

**Effort:** small-to-medium (1 is an hour; 2–4 are a focused day with tests). **Risk:** low — all changes are additive at load/save time and the existing behavior suites pin the round-trips. **[S02: coordinate with M5 (phrase identity) and M2 (`uses`) in the same batch, per S01 §4 — one schema version bump absorbs all three.]**
