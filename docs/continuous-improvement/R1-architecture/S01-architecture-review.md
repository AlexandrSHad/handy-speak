# HandySpeak — Architecture Review (Maintainability & Ease of Future Change)

- **Date:** 2026-11-25
- **Scope:** `lib/` (31 hand-written Dart files, ≈5,500 LOC + 4 generated l10n files), `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`, repo/docs structure. **Tests were not modified** and are referenced only as context (file layout, support seams).
- **Method:** every hand-written file in `lib/` read in full; import graph extracted for all files (grep of `^import`); ARB key parity check across `en`/`cs`/`uk`; docs/planning cross-referenced against code.
- **Lens:** code maintainability and ease of future development/change (per request). Not a security or performance audit.

---

## 1. Executive summary

The codebase is in **unusually good shape for a POC**. It has a clean layered architecture (`core` ← `data` ← `state` ← `widgets`, with `services` at the platform edge), a genuine composition root with constructor injection, real seams over all three platform plugins, deep controllers with narrow interfaces, disciplined localization across three locales, and an exemplary documentation culture (4 ADRs, 11 planning documents, rationale-bearing doc comments).

The debt concentrates in three places, all fixable while the codebase is still small:

| Severity | Count | Theme |
|---|---|---|
| **Critical** | 3 | a data⇄state import cycle (broken layering), a 1,100-line god-file on the highest-churn surface, and a persistence layer with no schema/versioning and silent failure modes |
| **Middle** | 8 | token-system promise vs. 31 hardcoded font sizes, a dead `uses` data path, speak policy in the UI, duplicated listener plumbing, `Phrase` identity-by-text, settings boilerplate, watch/select inconsistency, no CI gate |
| **Low** | 10 | doc drift, minor layering nits, idiom inconsistencies, small traps |

Quick metrics (hand-written `lib/`): largest file `settings_dialog.dart` at 1,101 lines (≈20 % of the app); next `telemetry_service.dart` 656 and `keyboard_view.dart` 419; median ≈115 lines/file. Platform plugins are each imported by exactly one file (`flutter_tts` → `tts_engine.dart`, `shared_preferences` → `storage_service.dart`, `sentry_flutter` → `telemetry_service.dart` + `main.dart` init call) — near-perfect adapter discipline.

---

## 2. What was done well

### 2.1 Layered architecture with one-way dependencies (one exception — see C1)

Verified from the full import graph:

```
                 widgets/  (12 files)
                    │ imports
              ┌─────┴──────┐
              ▼            ▼
           state/        l10n/ (generated)
   (5 controllers)        
              │ imports
       ┌──────┴───────┐
       ▼              ▼
    services/        data/  (4 files)
 (speech, storage,   (keyboard_layouts, pictograms,
  telemetry, tts      symbol_categories, phrases_data)
  engine)                │ imports
       │                  ▼
       └────►  core/  (app_language, math_speak, letter_sounds,
                      theme, text_display, app_version)
```

- `core/` imports nothing app-internal (pure functions + enums + tokens). `data/` imports only `core/`. `state/` imports `core`+`data`+`services`. `widgets/` never imports a plugin.
- **Every platform plugin is confined to exactly one adapter file.** `flutter_tts` appears only in `tts_engine.dart:1`; `shared_preferences` only in `storage_service.dart:1`; `sentry_flutter` in `telemetry_service.dart:4` plus the one `SentryFlutter.init` call in `main.dart:7`. Swapping or faking any plugin is a one-file change.
- The single exception is the `phrases` pair (critical issue **C1**).

### 2.2 A real composition root — constructor injection, no service locator

`main.dart` (184 lines) constructs the entire object graph top-to-bottom: storage → speech → controllers → feedback coordinator, then injects via `MultiProvider` of **pre-built instances** (`ChangeNotifierProvider.value`). No hidden globals, no `get_it`, no lazy singletons. Side-effect wiring that doesn't belong to any controller (redaction ledger listener, `tts/ready` one-shot listener, startup breadcrumb) is done explicitly in one place with a comment explaining why each exists (`main.dart:62-105`). Every wiring decision cites its ADDENDUM/ADR.

### 2.3 Deep modules with narrow interfaces

- **`SpeechService`** (265 lines) exposes ~6 methods and hides: a 16 s init ceiling so a hung engine degrades to a visible "unavailable" instead of an eternal spinner (`speech_service.dart:44`); the flutter_tts 4.x `awaitSpeakCompletion` drop-utterance bug and its workaround, documented with the observed symptom (`speech_service.dart:130-139`); utterance preemption semantics ("newest intent wins", main vs. feedback channel so the Speak button never flickers on a keystroke); `tts/speak` transaction lifecycle with a timeout guard. Callers learn none of this.
- **`ComposerController`** (225 lines) routes two independent buffers (sentence/math) behind one `text` getter; a private `_active` setter keeps sentence-shaped mutators from ever corrupting the math buffer (`composer_controller.dart:85-91`). The math grammar itself is pure, Flutter-free functions in `core/math_speak.dart` — unit-testable without a widget tree.
- **`TtsEngine`** is a textbook seam: the abstract interface the service depends on, one dumb production adapter, one test fake (`test/support/fake_tts_engine.dart`), and the only `flutter_tts` import in the app.

### 2.4 Event-driven decoupling for cross-cutting reactions

`ComposerEvent` (sealed class, `composer_controller.dart:20-63`) lets `SpeechFeedbackController` react to *what kind of mutation happened* (letter typed, word finished, phrase loaded, math op) without diffing text — and the contract is written down: the UI must never consume `lastEvent`, only the out-of-tree coordinator does. The feedback controller itself is pure policy, owns nothing, and lives outside the widget tree (`speech_feedback_controller.dart:27-38`). This is the kind of interface that makes adding a fourth feedback behavior a 5-line switch case.

### 2.5 Documentation as architecture

- 4 ADRs (`docs/adr/`), 11 planning documents (`planning/`), plus `docs/forgiving-taps.md`, `docs/testing-strategy.md`, `docs/telemetry-research.md`.
- Doc comments don't describe *what* code does — they record *why*, with citations: language-set edge cases are numbered (Q5, Q7, Q12, Q16–Q18 in `language_controller.dart`), risks are named ("the dialog never remembers where the parent was last time, ADDENDUM-05 step 3"). This makes both human and AI navigation of the codebase feasible and makes *changing* a decision safe (you can find the decision).
- Known debt is self-acknowledged in-code, e.g. `settings_dialog.dart:106-111` admits the file is ~1000 lines and sketches the extraction.

### 2.6 Theme & design-token system

`AppColors` is a `ThemeExtension` with full `copyWith`/`lerp`, light + dark variants in parity, and a `context.colors` accessor. The "card input" idiom lives once in `InputDecorationTheme` (with a documented reason for the deliberately absent `contentPadding`, `theme.dart:250-257`). Dialog sizing breakpoints are derived, not duplicated (`dialogMinScreenW = dialogW + s24*2`, `theme.dart:217-220`). (Caveat: M1 — typography sizes are *not* tokenized.)

### 2.7 Localization discipline

- All three ARB files carry **identical key sets** (verified: 58 keys each, `lib/l10n/app_*.arb`), with correct per-locale plural rules (`=0{0 slov} =1{…} few{…} other{…}` vs. Ukrainian `one/few/many/other`).
- The generated files are committed; the template (`app_en.arb`) is the only hand-edit surface; regeneration is build-integrated (`l10n.yaml`).
- The UI-locale strategy is a *decision*, not an accident: locale pinned to the main language (ADR-0002), implemented in one `Consumer2` in `main.dart:158-167` with the rationale in a comment.
- Child-facing content data (phrases, pictograms, symbol labels) is per-language and data-driven; exhaustive `switch (l)` statements mean adding a language produces **compile errors** pointing at every site that needs a value, and each concern (layouts, letter sounds, math words, pictograms, seeds) lives in its own single file.

### 2.8 Accessibility-first engineering

`ForgivingTap` (`forgiving_tap.dart`) exists because `InkWell.onTap` cancels after `kTouchSlop` — silent input loss for exactly this audience. It ships with a root-cause doc, chosen semantics, a migration list, and a documented *exception* (parent-facing settings targets are standard Material — `settings_dialog.dart:273-277`). `DisplayCase.displayUpper()` (`text_display.dart`) cleanly separates stored text from displayed casing, with the invariant written in the file's only comment.

### 2.9 Privacy-by-design telemetry

`TelemetryService` (656 lines) encodes ADR-0004 as code: tag/breadcrumb/scope allowlists, a redaction ledger (composer text + utterance ring), per-scope message suppression where exception text echoes stored content, transaction filtering at creation because `beforeSend` never runs on transactions, and an in-memory sink that records in *both* modes so canary tests assert the contract. Telemetry failures are swallowed by design ("telemetry must never take the app down with it").

### 2.10 Defensive platform handling

TTS init failure → visible "unavailable" banner + disabled button, never a crash or a poisoned future (`speech_service.dart:108-127`); `hasVoiceFor` fail-opens so a probe failure can't hard-block language selection; `StorageService.init()` failure is instrumented then rethrown (`main.dart:46-53`); corrupt phrase JSON degrades to seeds *and* reports itself (`phrases_controller.dart:54-71`).

### 2.11 File hygiene

Median file ≈115 lines; `home_page.dart` is 67 lines of pure composition (select-based rebuilds, a `switch` over `InputMode`); only three files exceed 400 lines (the god-file C2, `telemetry_service.dart`, `keyboard_view.dart`). The test tree mirrors the lib tree (`test/unit/{core,data,state,services,widgets}`, `test/behavior/`, `test/support/` fakes/harness, one device smoke pair) — a shape future features can copy.

---

## 3. What was done badly

**Severity key** (from the maintainability/future-change lens):
- **Critical** — breaks a structural rule or risks data, and will block/mislead future development if left.
- **Middle** — causes rework, friction, or misleading behavior; has workarounds.
- **Low** — polish, drift, consistency; fix opportunistically.

### 3.1 Critical

---

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
```

- This is a mechanical move: no behavior change, imports in `phrases_controller.dart`, `phrases_data.dart`, and the two widget consumers stay valid (`widgets` already import the controller and read `Phrase` through it).
- To keep the rule from regressing: add a layering check that does not touch `test/` — e.g. a CI grep step (`grep -r "state/" lib/data/` must be empty), or a `custom_lint`/`import_rule` if the project ever adopts one. The `symbol_categories.dart` Material import can be fixed in the same pass (use `dart:ui`'s `Color`, or move category colors to `AppTokens`).
- **Effort:** small (an hour-level change). **Risk:** low (pure move; existing suites should pass unchanged since public names are identical). Good first pick.

---

#### C2. `settings_dialog.dart` — a 1,101-line god file owns the highest-churn parent surface

**Facts.**

- `lib/widgets/settings_dialog.dart` is 1,101 lines — 2.6× the second-largest widget file (`keyboard_view.dart`, 419) and ≈20 % of all hand-written code in the app.
- It contains **13 private widget classes** and at least as many concerns: dialog presentation (framed vs. full-screen breakpoint), navigation rail, three feature panes, a stateful async voice-probe state machine (with a generation counter to discard stale results), the documented reusable dropdown recipe, phrase CRUD UI, and a pinned add bar:

```
lib/widgets/settings_dialog.dart (1,101 lines)
├── showSettingsDialog()                 30–43    presentation + useRootNavigator decision
├── _SettingsDialog(+State)              50–146   layout, breakpoint, IndexedStack + rationale
├── _CategoryRail / _RailEntry           154–306  rail, version footer
├── _PaneHeader / _PaneScrollBody        311–401  shared pane chrome + scroll key
├── _LanguagePane                        403–427
├── _AccessibilityPane                   429–514  7 toggle rows
├── _SectionTitle                        516–546
├── _LanguageSection(+State)             557–753  voice probes, banners, 2 dropdowns, switch
├── _LanguageDropdownField               777–861  the card-input dropdown recipe (40-line doc comment)
├── _VoiceSection                        863–884
├── _ToggleRow                           886–936
└── _PhrasesPane(+State)                 944–1101 phrase list + pinned add bar
```

- The file's own comment plans this fix: *"The natural moment is when this ~1000-line file gets the Language section extracted into its own file"* (`settings_dialog.dart:108-111`).
- History confirms churn concentration: three of the last features (ADDENDUM-04 language set, ADDENDUM-05 settings redesign, ADDENDUM-08 speech-feedback toggles) all landed in this one file, and the deferred roadmap items (mood voices, per-surface active-language localization, the ADR-0002 settings toggle) will land here too.
- Test keys are spread across the whole file (`settingsVersion`, `settingsCategory_*`, `settingsLangDropdown_*`, `settingsLangItem_*`, `settingsSecondLangSwitch`, `settingsAddPhraseField`, `settingsPaneScrollable`) — any split must carry them unchanged.

**Why it matters for the future.**

1. Every parent-facing feature competes for the same file → merge conflicts, large review diffs, and a navigation cost that makes contributors *add* to the least appropriate neighbor rather than the right class.
2. The `_LanguageSectionState` voice-probe machine (6 listener fields, a generation counter, dual dependency listeners — `settings_dialog.dart:564-655`) is the most delicate stateful code in the app and sits buried at line 557 of a UI file. It is the piece most likely to break silently when touched.
3. The reusable *recipe* widgets (`_ToggleRow`, `_LanguageDropdownField` — the latter documented as "invariants to copy for any future dropdown") are private inside a file nobody else can import. The idioms the codebase treats as standards are not actually shared.

**Decisions that led here.** ADDENDUM-05 deliberately chose one popup `Dialog` with a rail and three panes, and an `IndexedStack` instead of a `switch` so pane state survives category switches (`settings_dialog.dart:84-119` — the comment records the reasoning, including the accessibility verification). Those decisions are good; they are also **orthogonal to file layout** — nothing about the IndexedStack requires the panes to live in the same file.

**What makes sense to add.**

```
lib/widgets/settings/
├── settings_dialog.dart          shell: showSettingsDialog, _SettingsDialog, breakpoint,
│                                 IndexedStack (children stay in enum order!)
├── pane_scaffold.dart            _PaneHeader, _PaneScrollBody (shared chrome)
├── language_pane.dart            _LanguagePane + _LanguageSection (+ its voice-probe state)
├── phrases_pane.dart             _PhrasesPane (+State)
├── accessibility_pane.dart       _AccessibilityPane
├── toggle_row.dart               _ToggleRow, _SectionTitle  → made importable
└── language_dropdown_field.dart  _LanguageDropdownField    → made importable (recipe preserved)
```

- Rules for the extracting agent: keep `showSettingsDialog()`'s signature and `useRootNavigator: false` (its comment explains the provider-scope trap, `settings_dialog.dart:33-40`); keep the `IndexedStack` children in `SettingsCategory` declaration order (`index` is the enum's `.index`, `settings_dialog.dart:102-104`); keep every `ValueKey` string identical; keep the panes stateful behavior unchanged.
- Second (optional) step the file's own comment sketches: hoist dialog-scoped session state (the phrase draft, the voice-probe results) into an object owned by `_SettingsDialogState` rather than relying on `IndexedStack`'s keep-alive side effect.
- **Effort:** medium (mechanical split, but behavior suites pin heights/keys — must run them). **Risk:** low if keys and mount order are preserved. Highest payoff-to-risk ratio of the three criticals for daily development comfort.

---

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
2. **Versioned load-time migration:** on `init()`, read `schema_version`; run ordered, pure migration steps (`String? migrateV1toV2(String raw)`) before controllers see data. Corrupt-blob handling becomes one place, not a per-controller `try/catch`.
3. **Observable writes:** route write failures through the existing telemetry seam (add a `storage/write` scope to the allowlist, tags = key name only, never values), and for phrase saves specifically surface an in-app `NoticeBanner` — silent loss of a parent's phrases is the worst failure this app can have.
4. **Backup before destructive fallback:** when phrases JSON fails to decode, rename the blob to `phrases_{lang}.corrupt` before re-seeding, so a support path can recover it. One extra `setString`.
5. Optionally, `debugPrint`-level round-trip verification of critical writes in debug builds.

**Effort:** small-to-medium (1 is an hour; 2–4 are a focused day with tests). **Risk:** low — all changes are additive at load/save time and the existing behavior suites pin the round-trips.

---

### 3.2 Middle

**M1. The token system promises a one-file reskin; 31 hardcoded `fontSize` literals say otherwise.**
`theme.dart:3-5` claims *"ALL visual styling lives here as tokens … centralizing colors/spacing/radii makes the reskin a find-and-replace rather than a rewrite."* Grep counts **31 `fontSize:` literals across 9 widget files** (16 of them in `settings_dialog.dart` alone), plus ad-hoc radii (14/12/16/18 next to `AppTokens.rKey`), fixed paddings (`EdgeInsets.all(3)` per key), and magic dimensions (symbol rail `SizedBox(width: 168)`, phrase strip `height: 56`, brand icon 40×40). Colors *are* centralized (good); **typography and per-component metrics are not**. When "the real HandySpeak design ships" (the stated plan), a reskin means editing every widget file — the exact rewrite the token doc promised to avoid. *Fix direction:* a type-scale block in `AppTokens` (`fontKey`, `fontTile`, `fontChip`, …) + shared `Key/Tile/Chip` widget shells whose metrics live once. Biggest single payoff after C2.

**M2. The `uses` counter is a write-never field presenting fabricated data.**
Seeds hardcode usage counts (42, 31, 28… `phrases_data.dart:9-16`); the settings pane displays them ("42× used", `settings_dialog.dart:1033`); `phrasesFor` sorts by them (`phrases_controller.dart:81`). No code increments `uses` — grep confirms zero mutation sites. Consequences: the "most used" ordering is frozen at seed values forever; parent-added phrases (uses 0) always sort last; the parent sees usage statistics that never were. *Fix direction:* either wire `PhrasesController.recordUse(lang, phrase)` into the phrase-tap path (composer `loadText` already emits `TextLoaded`), or remove the field, the sort, and the "used" label until it's real. A product decision, not just a code fix — flag it to the owner.

**M3. The "what gets spoken" policy lives in the UI layer.**
`speak_button.dart:104-107` decides that math-mode text is translated through `mathSpeak()` before speaking — a domain rule ("math glyphs are pronounced as words") implemented inside one button widget, importing `core/math_speak.dart` from the UI. `SpeechFeedbackController` owns a *different* subset of speech policy (feedback utterances). If any second surface ever speaks the message (phrase preview from settings, switch-access scanning, a notification), it must re-implement the translation rule or speak raw glyphs. *Fix direction:* move the decision behind the speech seam — e.g. `SpeechService.speakComposer(ComposerController, {feedback})` or an utterance-builder in the state layer — so the rule exists once. (Small: one method + two call sites.)

**M4. The reactive-listener plumbing is hand-rolled twice, ~50 lines each.**
`_KeyboardViewState` (language-change → reset `_numOpen`, `keyboard_view.dart:38-59`) and `_LanguageSectionState` (set-change/speech-ready → re-probe voices, with a generation counter, `settings_dialog.dart:564-655`) both hand-implement: cache the controller, `didChangeDependencies` diff, add/remove listener, dispose guard. The settings variant is the most fragile code in the app precisely because it's bespoke. *Fix direction:* one small helper — e.g. a `ListenableEffect` widget or a mixin `ControllerEffect<T extends Listenable>` — encapsulating attach/detach/diff, used by both. Fold into C2's extraction.

**M5. `Phrase` identity is text equality.**
`remove` deletes *every* phrase with the same text (`identical(p) || p.text == phrase.text`, `phrases_controller.dart:96`); `togglePin` toggles the *first* match (`indexWhere((p) => p.text == phrase.text)`, line 104); `add` performs no dedup. Two same-text phrases (easy for a parent to create — the add field doesn't check) produce: one delete click removes both; pin toggles the wrong one. *Fix direction:* stable id per `Phrase` (or dedup on add + identity by instance). Coordinate with C1's model move and C3's schema work — one combined migration.

**M6. `SettingsController` is 8 clones of the same boolean pattern.**
Each setting costs a key const, a field, a getter, a `load()` line, and a setter — ~10 near-identical lines × 8 (`settings_controller.dart:13-110`). Every future setting (mood voices, per-language overrides) adds another clone, and every consumer that only needs one boolean tends to `watch` the whole controller (see M7). *Fix direction:* a tiny `BoolPref` value object (`key`, `fallback`, read/write) or a generic `read/write` helper collapses the file to data. Nice-to-have, not urgent.

**M7. `watch` vs `select` discipline is inconsistent for identical leaf reads.**
`math_board.dart:81` and `symbol_board.dart:101,169` use `context.select<SettingsController, bool>((s) => s.bigLetters)` — the correct leaf read. `keyboard_view.dart:79` and `phrase_strip.dart:24` read the same boolean via `context.watch<SettingsController>()`, rebuilding the whole keyboard/strip when *any* of the 8 settings notifies. `_PhrasesPane` watches three controllers at once (`settings_dialog.dart:964-966`). At this scale it's a performance non-issue; the cost is that the rebuild-scope rules are tribal knowledge, and copies of the wrong idiom spread. *Fix direction:* one sentence in CLAUDE.md ("leaf reads use select; watch only when multiple fields are needed") + normalize the ~6 offending sites in one sweep.

**M8. No CI gate — quality depends on contributor discipline.**
No `.github/workflows/` exists; `analysis_options.yaml` is stock `flutter_lints` with zero custom rules; analyze + unit/behavior tests run only when someone remembers (`puro flutter analyze` / `puro flutter test`). The suites are genuinely valuable (see §2.11) but nothing enforces them on every change. *Fix direction:* a minimal Actions workflow (analyze + `flutter test test/`, no device needed) — the device smoke stays manual by design. Cheap insurance for exactly the "another agent implements fixes" workflow this review feeds.

### 3.3 Low

**L1. Documentation drift.** `CLAUDE.md` states SDK `>=3.4.0` while `pubspec.yaml:7` says `>=3.5.0`; its `lib/` tree omits 6 existing files (`tts_engine.dart`, `telemetry_service.dart`, `math_speak.dart`, `letter_sounds.dart`, `app_version.dart`, `speech_feedback_controller.dart`); it names `planning/IMPLEMENTATION_PLAN.md` but the file is `INITIAL_IMPLEMENTATION_PLAN.md`; `docs/forgiving-taps.md:91-96` points to a retired regression suite (`test/keytap_test.dart`, `integration_test/keytap_suite.dart` — neither exists; the smoke pair is `device_smoke_test/suite`). Stale docs actively mislead the next contributor. Cheap sweep.

**L2. `data/symbol_categories.dart` imports Flutter Material** (for `Color`, line 1) — the data layer isn't headless-reusable. Covered by C1's fix pass; a `dart:ui` import or theme-token colors both work.

**L3. Three tap idioms coexist on child-facing surfaces, and the migration trigger can't fire.** Keyboard keys use `ForgivingTap`; symbol tiles and phrase chips use plain `InkWell` (`symbol_board.dart:111`, `phrase_strip.dart:90`); mode/language toggles and word tiles use `GestureDetector` (`top_bar.dart:93`, `message_blocks.dart:92`). `docs/forgiving-taps.md:69-83` honestly lists the unmigrated candidates and sets the trigger "if dropped taps are reported there" — but nothing measures dropped taps, so the feedback loop never triggers. Consider a debug-mode dropped-tap counter, or just finish the migration while the surface count is small.

**L4. `AppLocalizations.of(context)!` appears 17× across 8 widget files.** A `context.l10n` extension (the codebase already has the `context.colors` precedent, `theme.dart:228-230`) removes the noise and the bang.

**L5. `StorageService._prefs` is `late final` with no guard** (`storage_service.dart:6-11`) — reading before `init()` throws a bare `LateInitializationError` with no hint. An assert with a message (or returning a ready-service from `init`) saves a future debugging session.

**L6. Side effect in build.** `MessageBar` tracks `_prevText` and schedules scroll animations from inside `build` (`message_bar.dart:56-58`). It works, but the "compare-and-act" belongs in a listener; future edits to rebuild flow (e.g. from M7 normalization) can silently change the scroll behavior.

**L7. SpeechService locale temporal coupling.** `setLanguage` before ready only records intent (`_locale`, `speech_service.dart:150-152`), and `_bind` applies it once; a `setLanguage` landing in the microtask window between `_bind`'s engine call and `status = ready` would be recorded but never applied to the engine. Current `main()` ordering makes this benign; a post-ready reconciliation (re-apply `_locale` once on ready) closes it permanently.

**L8. `TelemetryService` mixes testable policy with the SDK adapter in one 656-line class** — the codebase's own `TtsEngine` idiom (abstract seam + dumb adapter) would fit here as a `TelemetrySink`. Also, `SpeechService` and `PhrasesController` constructors default to `TelemetryService()` when the parameter is omitted (`speech_service.dart:33-35`, `phrases_controller.dart:39-40`) — each default is a *separate instance* with its own redaction ledger and sink. Documented and currently safe (production always passes the shared one), but it's a trap for a new call site: the seam exists, yet a forgotten parameter silently forks the redaction ledger.

**L9. Stringly-typed symbol category ids.** `kPictograms` is keyed by `String`, and `symbol_board.dart:31` does `firstWhere((c) => c.id == _symbolCategoryId)` without `orElse` — a diverging id pair throws a `StateError` at runtime. Both sides are const today, so it can't happen yet; a shared const id list (or an enum) makes the invariant compiler-checked.

**L10. No human-facing README at the repo root.** Onboarding currently runs through `CLAUDE.md`, which is written for agents. A short README (what the app is, how to run/test, where the docs live) costs 30 minutes and pays off for every future contributor.

---

## 4. Suggested sequencing for the implementing agent

If picking work off this report, the dependency-aware order:

1. **C1** (move `Phrase` to `lib/data/`, fix the `symbol_categories` Material import, add a layering guard) — smallest, unlocks all later refactors, no behavior change.
2. **M8** (CI workflow) — do before touching code, so every subsequent step is gated.
3. **C2** (split `settings_dialog.dart` by pane; preserve keys, `IndexedStack` order, `useRootNavigator: false`) — optionally fold M4 (listener helper) into the same PR.
4. **C3 + M5 + M2** (storage keys module, `schema_version` + migration hook, write-error telemetry + corrupt-blob backup, phrase identity, decide the `uses` question with the owner) — one persistence-themed batch.
5. **M1** (type tokens + shared key/tile/chip shells) — the reskin enabler; do before the real design lands, not after.
6. M3, M6, M7, L1–L10 — opportunistic, each independent.

Each critical above carries its own evidence and constraints so issues can be re-categorized or split without re-deriving them from scratch.
