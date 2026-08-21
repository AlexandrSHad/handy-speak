# HandySpeak — ADDENDUM-05: Settings Dialog

## Context

Settings stops being a bottom sheet and becomes a popup dialog divided into
three categories — Language, Phrases, Accessibility — navigated by a rail
pinned to the left. The decision and its rationale live in
`docs/adr/0003-settings-redesign.md`; the brief that produced the design
lives in `planning/ADDENDUM-05-design-handoff.md`; the delivered design is
`handoff/HandySpeak_Addendum-05.html` (a bundled React artifact — reference
only, never importable).

**This is a restructure, not a feature.** Every control that exists today
survives unchanged; none is added. Where the design mockup differs from the
shipped Flutter UI, the shipped UI wins unless this plan says otherwise.

### Decisions taken during the grilling session that produced this plan

The design was delivered without the `spec.md` it was asked for (and which
its own source cites twice), so the following were settled directly with the
user and are not recoverable from the artifact:

- **896×624**, not the mockup's 1040×704. Breakpoint moves to 944×672.
  The size is confirmed against the built app before ADR-0003 is final.
- **The rail is content-sized and unbounded**, not fixed at 168 pt. A fixed
  168 pt rail wraps `Parent · Phrases` (122.9 px measured) and
  `Батьки · Фрази` (117.8 px) at text scale 1.3 against 112 px of available
  text width — the exact truncation failure that disqualified top tabs.
- **The header X is always visible**, contradicting an earlier line in
  ADR-0003. The sheet already has one today.
- **Corner radius is `AppTokens.rCard` (22)**, not the mockup's 28.
- **Content is capped at a 640 pt measure.**
- **Accessibility ships three toggles.** The mockup's other five rows
  (switch scanning; four word-block gesture toggles) have no counterpart in
  `lib/` — scanning appears nowhere, and the word-block gestures are
  unconditional behaviour of which only tap-to-✕ is implemented at all.
- **Mood voices is untouched** — the disabled row exactly as it ships.
- **Dropped from the design**: the per-language chip in Phrases, the empty
  phrase-list state, the rail footer note, and the uppercase section-header
  styling (which is inherited prototype CSS, not a designed decision).
- **Kept from the design**: the add-row pinned to the pane bottom, and the
  two new category subtitles.
- **`settingsPhrases` loses its "Parent · " prefix** — that prefix models a
  parent/child settings tier `CONTEXT.md` says must not be modelled.

### Codebase facts that matter

- There is **no `showDialog` anywhere in `lib/`**, no breakpoint constant, no
  max-width constant, and no `MediaQuery` usage at all. The only size-aware
  widget is `symbol_board.dart:43`'s `LayoutBuilder`.
- `AppTheme._build` (`theme.dart:223-259`) currently sets only
  `scaffoldBackgroundColor`, `colorScheme`, `inputDecorationTheme`,
  `extensions`, `textTheme`, `splashFactory`. No `DialogTheme`.
- `AppColors` already has a `dividerSoft` token (`theme.dart:40`).
- The theme sets **no custom font family and no custom text sizes** — the app
  inherits stock Material 3 typography.
- Each suite's `run<Suite>()` body lives in `integration_test/<name>_suite.dart`;
  `test/<name>_test.dart` is a 7-line headless entry importing it. All three
  suites pump at 1280×800 / DPR 1.0, which stays in the fixed presentation
  under the new 944×672 breakpoint.
- No test imports `settings_sheet.dart` or calls `showSettingsSheet`; every
  suite reaches Settings through the `Icons.settings_outlined` gear.

---

## Implementation steps

### 0. Prep commit — symbol category rename

Ships **before** the dialog work, as its own commit. Pure rename, no
behaviour change. `CONTEXT.md` now defines **Symbol category** and reserves
the unqualified word for Settings, so the board's identifiers must stop
claiming it before `SettingsCategory` appears beside them.

- `lib/data/categories.dart` → `lib/data/symbol_categories.dart`
- `kCategories` (`:23`) → `kSymbolCategories`; the `SymbolCategory` class
  (`:7`) is already correctly named and does not change.
- `lib/widgets/symbol_board.dart`: import (`:8`), `_categoryId` (`:24`) →
  `_symbolCategoryId`, `_CategoryRail` (`:87`) → `_SymbolCategoryRail`, and
  the call sites at `:29-31`, `:36-39`, `:103`, `:106`.
- `lib/data/pictograms.dart:20` — doc comment says "grouped by category id";
  make it "symbol category id".
- `CLAUDE.md:49` — the project-layout line lists `categories`; update to
  `symbol_categories`.

Leave `planning/` and `handoff/` documents alone; they are historical records.

### 1. Tokens and dialog theme — `lib/core/theme.dart`

Add to `AppTokens` (class at `:190`, alongside the radii at `:203-209`):

```dart
/// Settings dialog: fixed size, and the screen below which it presents
/// full-screen. The breakpoint is derived so the two cannot drift apart —
/// it is the dialog plus `s24` of margin on every side (ADR-0003).
static const double dialogW = 896;
static const double dialogH = 624;
static const double dialogMinScreenW = dialogW + s24 * 2; // 944
static const double dialogMinScreenH = dialogH + s24 * 2; // 672

/// Longest line of body text inside a settings pane. The fix for the
/// full-width text measure that motivated the redesign.
static const double measureMax = 640;
```

Add a `DialogTheme` to `_build` (`:223-259`), beside the existing
`inputDecorationTheme`: `surface` background, `RoundedRectangleBorder` at
`rCard`, and `clipBehavior: Clip.antiAlias`. Do **not** put the size in the
theme — the dialog picks fixed or full-screen per screen and sets its own
constraints.

### 2. Strings — `lib/l10n/app_en.arb`, `app_cs.arb`, `app_uk.arb`

Edit in place (currently `:37` in each file):

| key | EN | CS | UK |
|---|---|---|---|
| `settingsPhrases` | `Phrases` | `Fráze` | `Фрази` |

Add three new keys. Place `settingsLanguageSet` next to `settingsLanguage`
(`:21`), and each `*Desc` next to the key it describes:

| key | EN | CS | UK |
|---|---|---|---|
| `settingsLanguageSet` | `Language set` | `Sada jazyků` | `Набір мов` |
| `settingsPhrasesDesc` | `Quick sentences the child can speak with one tap. Each language keeps its own list.` | `Rychlé věty, které dítě řekne jedním ťuknutím. Každý jazyk má vlastní seznam.` | `Швидкі речення, які дитина скаже одним дотиком. Кожна мова має власний список.` |
| `settingsAccessibilityDesc` | `How the board looks and feels. These apply to both languages.` | `Jak tabulka vypadá a reaguje. Platí pro oba jazyky.` | `Як дошка виглядає та реагує. Діє для обох мов.` |

`settingsLanguage`, `settingsPhrases` and `settingsAccessibility` become the
three category labels. `settingsLanguageDesc` stays where it is, as the
Language set section's subtitle. Regenerate with `puro flutter gen-l10n`.

### 3. The dialog — `lib/widgets/settings_sheet.dart` → `lib/widgets/settings_dialog.dart`

Rename the file and `showSettingsSheet` (`:16`) → `showSettingsDialog`.
Replace `showModalBottomSheet` (`:17`) with `showDialog`. **Mirror the
existing call's navigator usage** — the sheet resolves providers correctly
today, and `showDialog` defaults to the root navigator, which is the most
likely way to lose them.

Add the category enum, qualified per `CONTEXT.md`:

```dart
enum SettingsCategory { language, phrases, accessibility }
```

**Shell.** `Dialog` → `SizedBox(width: AppTokens.dialogW, height: AppTokens.dialogH)`
in the fixed case; in the full-screen case, `insetPadding: EdgeInsets.zero`
with a zero-radius shape and the size driven by the screen. Choose between
them from `MediaQuery.sizeOf(context)` against `dialogMinScreenW/H` — two
states, no interpolation. It must stay a `Dialog`, never a pushed route: the
board has to remain in the widget tree beneath the scrim or existing finders
lose it.

State: the selected `SettingsCategory`, initialised to `.language` on every
open. It never remembers.

**Rail.** A `Column` inside an `IntrinsicWidth` so it sizes to its longest
label and can never wrap — three entries, so the intrinsic pass is
negligible. Unbounded by decision (see Risks). Each entry: leading icon,
`s12` gap, label in the app's existing text style, `minHeight: 52` matching
`settings_sheet.dart:417`'s existing language-menu floor. Selected entry gets
a `primarySoft` fill and a 4 pt `primary` left bar; unselected uses `ink2`.
Rail background `surface2` against the pane's `surface`, with a `divider`
rule between them. The rail carries the "Settings" title (`settings` key) at
its top and does not scroll.

Give each entry `ValueKey('settingsCategory_<name>')` — the suites need a
deterministic way to switch category.

**Pane.** Header row: category title, optional subtitle, then the X
(`Icons.close`, tooltip `closeLabel`) at the trailing edge — always present.
Body: a scroll view keyed `ValueKey('settingsPaneScrollable')`, its child
wrapped in `ConstrainedBox(maxWidth: AppTokens.measureMax)`, left-aligned.

**Category contents.** Reuse the existing widgets wholesale — `_SectionTitle`,
`_ToggleRow`, `NoticeBanner` and the dropdown recipe all stay exactly as they
are:

- **Language** — `_LanguageSection` (`:242-320`) retitled from
  `settingsLanguage` to `settingsLanguageSet`; the refresh `IconButton`
  (`:257-270`) **stays in that section header**, not in the pane header.
  Then `_VoiceSection` (`:444-451`) unchanged, Mood voices still disabled
  with `onChanged: null` at 0.45 opacity.
- **Phrases** — the show-shortcuts toggle (`:577-583`), the hidden note
  (`:584-602`) and the list (`:609-634`) scroll in the body. The add row
  (`:642-658`) moves **out of the scroll view** into a bar pinned to the
  pane bottom with a `divider` top rule, because the list is uncapped.
  No inner section header: the pane title already says Phrases.
- **Accessibility** — `_AccessibilitySection`'s three toggles (`:468-485`).
  No inner section header, for the same reason.

Whatever `ForgivingTap` usage exists on the per-phrase pin/delete controls
today carries over untouched — check `docs/forgiving-taps.md`'s migration
list before moving those rows.

### 4. Call site — `lib/widgets/home_page.dart:36`

`TopBar(onOpenSettings: () => showSettingsDialog(context))`, and the import
at `:14`. This is the only call site in `lib/`.

### 5. Suite migrations

**`integration_test/addendum01_suite.dart`** — its controls now span two
categories, so it needs category navigation it never had.

- `settingsScrollable()` (`:427-429`) currently finds the first `Scrollable`
  inside `BottomSheet`. Retarget to `find.byKey(const ValueKey('settingsPaneScrollable'))`.
- Add `openCategory(tester, name)` tapping `ValueKey('settingsCategory_$name')`.
- `tapToggle` (`:439-450`) gains a category argument. Big letters and
  Haptics (`:53-55`) are in Accessibility; `settingsShowPhrasesName`
  (`:188`, `:232`, `:279`), `settingsPhrasesHiddenNote` (`:190`) and the
  phrase editor (`:209-217`) are in Phrases.
- `closeSettings` (`:419-424`) uses `find.byIcon(Icons.close).first` and a
  comment about tree order. The header X now sits in the pane, which comes
  after the rail but still before the phrase rows — **verify that `.first`
  still resolves to the header**, and switch to the `closeLabel` tooltip if
  it does not.

**`integration_test/addendum03_suite.dart`** — least affected; both language
dropdowns land in the same category. **One real trap**: `:170` dismisses an
open dropdown menu with `tester.tapAt(const Offset(640, 30))`. At 1280×800
the dialog now spans x 192–1088, y 88–712, so (640, 30) lands on the
**scrim** and dismisses the whole dialog instead of the menu. Every assertion
after it would then fail in a way that looks like a dismissal bug. Retarget
to a neutral point inside the pane.

**`integration_test/addendum04_suite.dart`** — the drag loop at `:228-236`
(`while` … `tester.drag` on the `ListView` inside the `BottomSheet`) is
**deleted**: with the add row pinned to the pane bottom the phrase
`TextField` is always on screen. The height-parity assertion (`:222-243`)
measures across two category visits — dropdown in Language, switch, field in
Phrases — and keeps its `closeTo(inputH, 1.0)` tolerance at scales 1.0 and
1.3. `closeSettings(tester, closeLabel)` (`:384-387`) still works unchanged.

### 6. New suite — `addendum05`

Create the pair via the `handyspeak-suites` skill:
`integration_test/addendum05_suite.dart` with `runAddendum05Suite()`, plus
`test/addendum05_test.dart` and `integration_test/addendum05_test.dart`.
Assertions:

- Opens on Language every time — open, switch to Phrases, close, reopen,
  expect Language.
- The rail shows all three category labels, localized (EN and CS).
- Tapping a rail entry swaps the pane content and leaves the rail in place.
- Instant apply survives a category switch and an app restart.
- At 1280×800 the dialog is smaller than the screen; at 900×600 it fills it.
- A description `Text` inside the pane is no wider than `AppTokens.measureMax`.
- The X dismisses; a scrim tap dismisses.
- The Phrases add row is reachable without scrolling.
- `settingsPhrases` renders without a "Parent" prefix in all three locales.

---

## Commit sequence

1. **Prep**: symbol category rename (step 0). `puro flutter analyze` clean.
2. **Tokens**: `AppTokens` additions + `DialogTheme` (step 1). Additive only.
3. **Strings**: ARB edits + `gen-l10n` (step 2). Additive plus one in-place
   edit; nothing consumes the new keys yet.
4. **Dialog**: the rename, shell, rail and category routing (steps 3–4).
   The large one; suites are red between here and commit 5.
5. **Suite migrations**: addendum01 / 03 / 04 (step 5). Back to green.
6. **New suite**: addendum05 pair (step 6).

## Risks

- **The rail is unbounded by decision.** At large system text scales it can
  grow to consume an arbitrary share of an 896 pt dialog, and past that point
  it will overflow with a `RenderFlex` stripe rather than degrade. This is
  the documented accepted gap in ADR-0003; the mitigation if it bites in
  practice is a max-width clamp with wrapping beyond it, which was
  considered and rejected.
- **`showDialog` and providers.** The sheet resolves controllers today; the
  root-navigator default is the likeliest way to break that. Mirror the
  existing navigator usage rather than accepting the default.
- **`addendum03`'s `tapAt(640, 30)`** silently becomes a scrim tap. Highest
  chance of a confusing red in the whole migration — the failure looks like
  the dialog dismissing itself.
- **`Icons.close` is used twice** — the header X and every phrase row's
  delete. `addendum01` relies on tree order via `.first`. Restructuring the
  tree is exactly what invalidates that assumption.
- **896×624 is chosen from a mockup.** It is a claim about composition, not
  about Flutter layout. Confirm on a real tablet before ADR-0003 is final;
  the Language category with both voice-pack banners and the
  unsupported-device banner is the state to look at, since it is expected to
  scroll.
- **Full-screen must stay a dialog.** An opaque route pushes the board
  offstage and several existing finders stop seeing it.

## Verification

### Unit tests

- [ ] `dialogMinScreenW/H` derive from `dialogW/H` + `s24 * 2` — assert the
      relationship, not the literals, so they cannot drift.
- [ ] All three new keys resolve in EN, CS and UK; `settingsPhrases` contains
      no "Parent" / "Rodič" / "Батьки" prefix in any locale.
- [ ] `puro flutter test` — all four suites green headless.

### Integration tests

- [ ] `addendum01` — toggles reachable across two categories; persistence.
- [ ] `addendum03` — language dropdowns, voice warnings, refresh and close;
      menu dismissal no longer hits the scrim.
- [ ] `addendum04` — height parity across two category visits at scale 1.0
      and 1.3; second-language switch and off-hint.
- [ ] `addendum05` — the new suite above.

### Manual checks

- [ ] On a real Android tablet: 896×624 at 1280×800 — does the board read as
      present behind the scrim? This is the open confirmation ADR-0003 needs.
- [ ] Full-screen presentation below 944×672.
- [ ] EN, CS and UK rail labels at text scale 1.0 and 1.3 — nothing wraps,
      nothing clips, the rail width changes with the locale.
- [ ] Dark mode across all three categories.
- [ ] iOS note (deferred, not built): the full-screen presentation will need
      `SafeArea` around the pane header and the pinned add row.

### AAC checklist

- [ ] Contrast: `primarySoft` on `surface2` for the selected rail entry in
      both themes.
- [ ] Shape simplicity: rail icons stay single-weight line glyphs.
- [ ] No realistic faces — none introduced.
- [ ] Touch targets: rail entries ≥ 52 pt. Settings is parent-facing, so
      standard Material target sizes are an accepted documented exception;
      the child-facing 72 pt `minTap` does not apply here. Existing
      `ForgivingTap` usage in the phrase rows carries over unchanged.

## Deferred (explicitly out of scope)

- **The sparse Accessibility category is unsolved.** Three toggles in a
  624 pt pane, mitigated only by the new subtitle. Revisit when a fourth
  setting exists rather than inventing one to fill it.
- Switch scanning and the four word-block gesture toggles the mockup shows —
  no counterpart in `lib/`.
- The per-language chip, the empty phrase-list state, and the rail footer
  note from the design.
- `docs/design/addendum-05/spec.md` — not written by the design session and
  deliberately not reconstructed; ADR-0003 and this plan carry the record.
- Renaming suites off their ADDENDUM numbers — a standing wish, still not
  this change.
- **Dialog-scoped session state.** The phrase draft and the voice-probe
  fields are kept alive by the `IndexedStack` holding the panes mounted — the
  right lifetime, obtained as a side effect rather than declared. They belong
  in an object owned by `_SettingsDialogState` and passed to the panes; the
  natural moment is the split of the ~1000-line `settings_dialog.dart`, with
  the Language section moving to its own file.

## Critical files

- `CONTEXT.md`
- `CLAUDE.md`
- `docs/adr/0003-settings-redesign.md`
- `lib/core/theme.dart`
- `lib/data/categories.dart` → `lib/data/symbol_categories.dart`
- `lib/data/pictograms.dart`
- `lib/widgets/symbol_board.dart`
- `lib/widgets/settings_sheet.dart` → `lib/widgets/settings_dialog.dart`
- `lib/widgets/home_page.dart`
- `lib/l10n/app_en.arb`, `app_cs.arb`, `app_uk.arb` (+ generated)
- `integration_test/addendum01_suite.dart`
- `integration_test/addendum03_suite.dart`
- `integration_test/addendum04_suite.dart`
- `integration_test/addendum05_suite.dart` (new)
- `test/addendum05_test.dart`, `integration_test/addendum05_test.dart` (new)
