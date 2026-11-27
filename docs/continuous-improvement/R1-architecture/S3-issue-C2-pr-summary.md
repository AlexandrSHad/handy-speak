# S3 — PR summary: issue C2, the `settings_dialog.dart` split into `lib/widgets/settings/`

- **Issue:** C2 from [S01-architecture-review.md](S01-architecture-review.md) §3.1, as analyzed and amended in [S02-issue-C2.md](S02-issue-C2.md) — the 1,101-line god file owning the highest-churn parent surface.
- **Branch:** `r1/c2-settings-split`, a plain branch off `main` (C1 is already merged, so the worktree parallelism the sequence sketched is moot). Not merged by the builder; the human merges, the gatekeeper approves.
- **Date:** 2026-11-27
- **Gate (the only one — M8/CI is deferred, S02 §2):** `puro flutter analyze` — **No issues found** · `puro flutter test` — **338/338, all passing** (main's exact count; no tests added — the split is behavior-preserving and the S02 pinning suites already exist). The S02 §4 verification list (c) — the six dialog suites — was also run standalone first: **67/67**.

## 1. What changed

The 1,101-line `lib/widgets/settings_dialog.dart` became seven files (1,078 lines total) under `lib/widgets/settings/`, exactly the layout S02 §4 prescribes:

| File | Lines | Contents |
|---|---|---|
| `lib/widgets/settings/settings_dialog.dart` | 282 | **new** — the shell: `showSettingsDialog` (doc + `useRootNavigator` comment verbatim), `SettingsCategory`, `_SettingsDialog(+State)` with the breakpoint and the `IndexedStack` (children in enum order), `_CategoryRail`, `_RailEntry`. |
| `lib/widgets/settings/language_pane.dart` | 250 | **new** — `LanguagePane`, `_LanguageSection(+State)` with the whole voice-probe machine (generation counter, dual listeners, dispose guards) moved verbatim, and `_VoiceSection`. |
| `lib/widgets/settings/phrases_pane.dart` | 167 | **new** — `PhrasesPane(+State)`; the class doc comment moves verbatim. |
| `lib/widgets/settings/language_dropdown_field.dart` | 107 | **new** — `LanguageDropdownField` (public per S02); **the 40-line recipe doc comment moves verbatim**, and CLAUDE.md's pointer follows it (§1 last row). |
| `lib/widgets/settings/accessibility_pane.dart` | 93 | **new** — `AccessibilityPane` (7 toggle rows + speech-feedback group). |
| `lib/widgets/settings/pane_scaffold.dart` | 91 | **new** — `PaneHeader`, `PaneScrollBody` (public per S02); docs verbatim; the `settingsPaneScrollable` key unchanged. |
| `lib/widgets/settings/toggle_row.dart` | 88 | **new** — `ToggleRow`, `SectionTitle` (public per S02). |
| `lib/widgets/settings_dialog.dart` | — | **deleted** (1,101 lines). |
| `lib/widgets/home_page.dart` | 2 | **S02 addition (a):** the sole caller's import `settings_dialog.dart` → `settings/settings_dialog.dart` (same position in the sorted import block). |
| `CLAUDE.md` | 3 | **S02 addition (b):** "Dropdowns follow the `LanguageDropdownField` recipe in `lib/widgets/settings/language_dropdown_field.dart`" — new public name and path. |
| `docs/forgiving-taps.md` | 3 | The rail-entry exception's path → `lib/widgets/settings/settings_dialog.dart` (see §3 item 4). |

No pubspec, l10n/ARB, generated-file, `test/`, or `integration_test/` changes. No behavior change: a pure mechanical split plus the S02 additions (a)/(b).

## 2. The one necessary spec deviation: the panes are public too

The S02 §4 tree writes the panes with underscore names (`_LanguagePane`, `_PhrasesPane`, `_AccessibilityPane`), keeping them private. That does not compile after the split: the shell's `IndexedStack` **constructs** the panes, and Dart privacy is **library**-scoped — `_LanguagePane` in `language_pane.dart` is not nameable from `settings_dialog.dart` (two separate libraries). The only alternatives would be inventing public factory functions the spec does not ask for, or making the files `part`s of the shell library, which would defeat "made importable" for the recipe widgets.

So the three pane widgets got the same transformation the S02 file itself prescribes for the five recipe/chrome widgets (`[S02: made public]` / `[S02: renamed public]`): the underscore dropped. Nothing else changed — the S02 analysis missed this simply because its tree lists per-file contents, not the shell's cross-file references. No test can observe the rename: no suite references the pane types (they were unreferenceable while private — S02 §3 verified this), and the key/mount-order contracts are byte-identical.

## 3. Small beyond-verbatim details (for the gatekeeper to scrutinize)

Everything in the moved code is byte-identical except these five items — mechanically verified (see §4):

1. **`super.key` on the eight public constructors.** `use_key_in_widget_constructors` fires for public widget constructors lacking a `key` parameter; the old privacy suppressed the lint. No call site passes a key (the dialog's test keys are all placed on inner widgets and stay exactly where they were), so this is behavior-neutral — but it is a constructor-signature addition on `PaneHeader`, `PaneScrollBody`, `ToggleRow`, `SectionTitle`, `LanguageDropdownField`, `LanguagePane`, `PhrasesPane`, `AccessibilityPane`.
2. **Brief doc comments on the four newly-public classes that had none** (`LanguagePane`, `AccessibilityPane`, `ToggleRow`, `SectionTitle` — Effective Dart public-API documentation). `PhrasesPane`, `PaneHeader`, `PaneScrollBody`, and `LanguageDropdownField` moved their existing docs verbatim.
3. **The `Deferred:` paragraph in the shell's `IndexedStack` rationale** had its last sentence updated: "The natural moment is when this ~1000-line file gets the Language section extracted into its own file" became "The natural moment — the Language section extracted into its own file (C2) — has arrived; the hoisting itself is still deferred." The hoisting (S02's optional second step) is **not** done — deliberately out of scope, exactly as instructed.
4. **`docs/forgiving-taps.md`'s one path reference** to the rail entries moved to `lib/widgets/settings/settings_dialog.dart`. Not on the S02 additions (a)/(b) list, but the builder's standing guardrail is "doc references the issue moves update in the same pass," and a stale path there would be exactly the doc-drift failure S02 addition (b) warns about. One line, flagged here for scrutiny.
5. **M4 (the listener helper) is NOT folded in** — the S02 sequence offered it as optional; the conductor's instruction was "do NOT fold in M4." The voice-probe machine moved verbatim, warts and all.

## 4. Verification — constraints preserved, move proven verbatim

The S02 §4 extracting-agent rules, each checked:

- `showSettingsDialog()`'s signature and `useRootNavigator: false` — verbatim, including the provider-scope-trap comment.
- `IndexedStack` children in `SettingsCategory` declaration order (`language, phrases, accessibility`; `index` is the enum's `.index`) — verbatim.
- Every `ValueKey` string byte-identical: `settingsVersion`, `settingsCategory_${name}`, `settingsPaneScrollable`, `settingsSecondLangSwitch`, `settingsLangDropdown_${slot}`, `settingsLangItem_${slot}_${lang}`, `settingsAddPhraseField`.
- Pane stateful behavior unchanged: the voice-probe machine and the `TextEditingController`/pinned-add-bar ownership moved line-for-line; `settings_test.dart`'s "half-typed phrase survives a category round-trip" and "dialog opens on Language every time" pass unchanged.

**The verbatim claim is mechanical, not asserted:** the old file (from `git show HEAD:`) and the concatenation of the seven new files were compared as exact per-line-count multisets after applying only the eight public renames and normalizing the `super.key` insertions. The complete diff is: the 14 doc-comment lines of §3 item 2, one `///` separator, the 3-for-2 Deferred-sentence swap of §3 item 3, and two lines that are artifacts of the rename normalization itself (`_PhrasesPaneState` — identical in both, only the normalization's `_PhrasesPane`→`PhrasesPane` rewrite makes them look different). Every other line of the 1,101 appears exactly the same number of times in the seven files.

Gate runs: `puro flutter analyze` → **No issues found**; the six S02 §4(c) suites standalone → **67/67**; full `puro flutter test` → **338/338 All tests passed**, identical to `main`'s count (the ADDENDUM-04 height-parity tests at text scales 1.0/1.3 — the reason heights could not drift — are inside that run and pass).

## 5. Merge notes (for the integrator, per S02 §5)

1. Merge `r1/c2-settings-split` into `main`, then re-run `puro flutter analyze` + `puro flutter test` on the combined result (expect zero issues / 338 passing).
2. No overlap with anything merged since the branch point (branched off post-C1 `main`; the only files touched are the dialog, its new home, the one-line caller import, and the two doc pointers).
3. C3's `_PhrasesPane` save-failure banner now lands in `settings/phrases_pane.dart` — exactly where S02 §4 already plans it; the sequence's "worst kind of conflict" warning (C2 deletes/splits the file C3 edits inside) is resolved by this split.
4. The device smoke is untouched (S02 verified it references no dialog keys; nothing under `integration_test/` changed) — still a manual, per-release run.
5. M4 remains open as its own future change: both `keyboard_view.dart`'s `_numOpen` plumbing and the moved `_LanguageSectionState` still hand-roll the same attach/detach/diff pattern.

## 6. Review follow-ups

No review rounds yet — this section fills after each gatekeeper round, with the gate re-run and the branch pushed after every one.
