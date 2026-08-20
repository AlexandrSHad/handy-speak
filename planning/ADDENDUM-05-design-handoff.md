# Design Handoff — ADDENDUM-05: Settings Dialog Redesign (UI/UX only)

You are designing one surface: the redesigned **Settings dialog** for
HandySpeak. The domain model, the category structure and the interaction
rules are **settled** — your job is presentation: layout, states, and copy.
Read `CONTEXT.md` (glossary — use these exact terms), `CLAUDE.md` (project
context), and `docs/adr/0003-settings-redesign.md` (the decision you are
designing) before starting.

## Non-negotiables (do not redesign or rename)

- Terminology per `CONTEXT.md`. The surface is the **Settings dialog** — a
  popup dialog by nature, which *presents* full-screen on small screens.
  Never "sheet", "screen", "page", or "modal". Its top-level divisions are
  **categories**; the titled groups inside a category are **sections**.
  Do not call categories "tabs" — that word already names the board's
  Keyboard/Symbols/Math toggle in this codebase.
- **Three categories, in this order: Language, Phrases, Accessibility.**
  Contents are fixed (see "What goes where"). Do not add, merge, split or
  reorder them. In particular: Voice is a *section* inside Language, not a
  fourth category.
- **Navigation is a rail pinned to the left**, in both presentations. The
  dialog always opens on **Language**; it never remembers the last category.
- **Instant apply.** Every control persists the moment it changes. There is
  no Save, no Done, no Apply, no discard prompt, no dirty state.
- **Dismissal**: scrim tap, Android back, and a header X. When presenting
  full-screen, the X alone.
- **Every setting is a parent setting.** No parent/child tier, no PIN, no
  gate, no "advanced" section. The entry point stays exactly as it is: the
  gear `IconButton` at the trailing edge of the top bar.
- **Voice-pack warning banners and the unsupported-device-language banner
  live inside the Language category only.** No global banner strip, no
  warning badge on the rail.
- **No flags** anywhere in language items — flags represent countries, not
  languages. Language items are a short-code chip plus the endonym.
- The **Mood voices** row stays, permanently disabled and greyed (it is
  out of scope for the POC by decision, not by accident). Design it as a
  disabled row; do not remove it and do not make it look actionable.
- Do not redesign the top bar, the boards, the message bar, or the Speak
  button. Nothing outside the Settings dialog is in scope.

## Project context

- AAC tablet app for non-verbal / speech-impaired children; **parents
  configure, children use**. Landscape-locked tablet, Android today (iOS a
  stated target — note safe-area concerns where relevant, nothing more).
- Flutter + Material, light and dark themes. Brand color `#1fa567`.
  Theme tokens (use as CSS variables in mockups): `bg`, `surface`,
  `surface2`, `surface3`, `ink`, `ink2`, `ink3`, `primary`, `primaryPress`,
  `primarySoft`, `divider`. Spacing scale 4/8/12/16/24/32/48; radii
  `rInput` 16, `rCard` 22, `rPill` 999; `minTap` 72. Exact values in
  `lib/core/theme.dart`.
- Inputs follow the app-wide **card-input idiom** — `surface2` fill, 16 px
  radius, divider border turning `primary` on focus — supplied by the
  theme's `InputDecorationTheme`. Never hand-roll input chrome. Dropdowns
  follow the existing `_LanguageDropdownField` recipe: closed state is a
  bare text line, **never a fixed height**, so fields grow with system text
  scale. Height parity between the dropdown and the phrase input is pinned
  by tests at text scale 1.0 and 1.3.
- Localization: EN is the template, CS and UK are full locales. Any new
  copy must be proposed in all three. Czech and Ukrainian words are long —
  *Přístupnost* / *Доступність* for "Accessibility" — and must not truncate.
- Accessibility: motor impairment is the core audience. Child-facing
  surfaces need large forgiving targets; **Settings is parent-facing, so
  standard Material target sizes are acceptable there** — a documented
  exception. Language menu items keep a 52 px minimum.

## Geometry (settled, but see the one open experiment)

- Fixed **1040 × 704**, `rCard` corners on all four sides, centered.
- Presents **full-screen** when the screen cannot frame it with at least
  24 pt of margin on every side — i.e. width < 1088 or height < 752. Two
  states only, no intermediate shrink-to-fit.
- Reference tablet is **1280 × 800** (what every test suite pumps at):
  that yields a dialog with 120 pt side margins and 48 pt top/bottom.
- Only the content pane scrolls — never the rail. Language and
  Accessibility should fit without scrolling at text scale 1.0. **Phrases
  will always scroll**: the phrase list is uncapped and ships 8 seeded
  phrases per language.

## What goes where (fixed)

**Language** — the category the dialog opens on.
- *Section: Language set.* Header (`settingsLanguage` / `settingsLanguageDesc`)
  with the refresh-voices icon action; the unsupported-device-language
  banner when present; main-language dropdown
  (`settingsMainLangName` / `settingsMainLangDesc`); its voice-pack banner;
  the second-language Switch (`settingsSecondLangName` / `…Desc`); then
  either the second-language dropdown plus its voice-pack banner, or the
  off-hint (`settingsSecondOffHint`).
- *Section: Voice.* `settingsVoice` header; the disabled Mood voices row.

**Phrases**
- Show-phrase-shortcuts toggle (`settingsShowPhrasesName` / `…Desc`) and,
  when off, the hidden-note line (`settingsPhrasesHiddenNote`).
- The phrase list: pin marker, phrase text, "N× used" count, Pin/Unpin
  action, delete action.
- The add row: text field (`settingsAddPhrase`) plus the Add button.

**Accessibility**
- Big letters, Haptics, Dark mode toggles.

## States to cover in mockups

| # | State |
|---|-------|
| 1 | Language category, single-language (second Switch off, off-hint shown) |
| 2 | Language category, second language enabled |
| 3 | Language category, voice-pack banner under main / under second / both |
| 4 | Language category, unsupported-device-language banner present |
| 5 | Language category, a dropdown open over the content pane |
| 6 | Phrases category, seeded list (8 phrases, some pinned) — mid-scroll |
| 7 | Phrases category, empty list (all phrases deleted) and shortcuts off |
| 8 | Accessibility category (the sparsest — show how it reads with room to spare) |
| 9 | Fixed-dialog presentation at 1280 × 800, board visible behind the scrim |
| 10 | Full-screen presentation at 1024 × 768 |
| 11 | Every category at text scale **1.3** |
| 12 | Light and dark theme; EN and CS renders (UK a bonus) |

## Open questions your design must answer

- **The rail itself.** A Claude-Desktop-style vertical list, a Material
  `NavigationRail`, or something else — argue for one. Icons plus labels, or
  labels alone? Selected-state treatment (`primarySoft` fill, left bar,
  something else)? How does it behave at text scale 1.3 with the Czech and
  Ukrainian labels? Rail width: the symbol board uses a fixed 168 pt rail —
  match it, or justify a different number.
- **Dialog chrome.** Where the title lives relative to the rail, where the X
  sits, whether the rail spans the full height or starts below a header,
  whether there is a divider between rail and content. This is the app's
  first dialog, so there is no existing idiom to match — you are setting it.
- **Section treatment inside a category.** Language holds two sections and
  Accessibility holds one. How is a section boundary expressed — the current
  bold title plus subtitle, a card, a divider, whitespace alone?
- **The phrase editor now owns a whole category.** Its rows were designed to
  be compact in a crowded list; with room, should a phrase row become a
  card? Where does the add-row sit — pinned to the bottom of the pane, or
  at the end of the list? What does the empty state say?
- **The sparse-category problem.** Accessibility is three toggles in a
  704 pt-tall pane. Show what that looks like without it reading as broken
  or unfinished.
- **Copy** for anything new: the three category labels reuse existing keys
  (`settingsLanguage`, `settingsPhrases`, `settingsAccessibility`) — confirm
  they read well as *category* labels in all three locales, and propose
  replacements if they do not.

### One live experiment

The geometry above is the decided default, but **also mock an
always-full-screen variant** and make the case either way. Always-full-screen
would delete the breakpoint, the second layout state and the scrim semantics
entirely — a real simplification. Against it: a full-screen takeover is
heavy for a parent making a ten-second change, and the child's board
vanishes. Show both at 1280 × 800 side by side. The decision is made after
this design session, not during it.

## Deliverables

Put everything in `docs/design/addendum-05/`:

1. `mockups.html` — one self-contained file (inline CSS, no external deps,
   no build step) with an in-page control bar to switch category, state
   (1–12), light/dark, EN/CS(/UK), text scale 1.0/1.3, and
   fixed-vs-full-screen presentation. Render inside a landscape tablet frame
   at true aspect, with the board and top bar visible behind the dialog.
   Use the theme tokens as CSS variables.
2. `spec.md` — your resolutions to the open questions with rationale, a
   state-by-state walkthrough, your recommendation on the fixed-vs-
   full-screen experiment with the evidence for it, and any proposed new
   strings as a table (key, EN, CS, UK) ready to become ARB entries.

Do not modify anything outside `docs/design/addendum-05/`. No Flutter code,
no pubspec changes, no ARB edits, no changes to files listed under
Non-negotiables.

## What happens next

This handoff feeds a design session; its output returns to a follow-up
grilling session, which produces the ADDENDUM-05 implementation plan. The
implementation lands as a single change: dialog container, breakpoint and
`DialogTheme` tokens, rail and category routing, section regrouping, the
`settingsShowPhrases*` ARB keys moving into a Phrases block, the
`settings_sheet.dart` → `settings_dialog.dart` and `showSettingsSheet` →
`showSettingsDialog` rename, the migration of the `addendum01`/`03`/`04`
suite helpers, and a new ADDENDUM-05 suite.

---

## Outcome (closed)

Delivered as `handoff/HandySpeak_Addendum-05.html`. Reviewed and closed in a
follow-up grilling session; the resulting plan is
`planning/ADDENDUM-05-settings-dialog-plan.md` and `docs/adr/0003-settings-redesign.md`
has been revised in place.

**Answered by the design**: the rail (list, icons plus labels, `primarySoft`
fill with a left bar), the dialog chrome (rail carries the title and spans
full height; X in the pane header), section treatment, and the phrase editor
(add row pinned to the pane bottom).

**Not answered**:

- *The live experiment* — no always-full-screen artboard was produced.
  Artboard 10 is the breakpoint case at 1024×768, which is a different thing.
  Resolved afterwards against the delivered mockup: the fixed dialog shrank
  from 1040×704 to 896×624 rather than becoming full-screen.
- *The sparse-category problem* — filled with five rows that do not exist in
  `lib/`. Still open; Accessibility ships three toggles.
- *`spec.md`* — never written, though the delivered source cites it twice by
  section number. Deliberately not reconstructed.
- *States 7, 11 and the Ukrainian render* — not mocked. Text scale 1.3 is
  verified in the built app instead.

**Deviations adopted**: the 640 pt measure cap, the pinned add row, the two
category subtitles, and the always-visible X.
**Deviations rejected**: 28 pt corners (`rCard` is 22), the uppercase section
headers, the phrase-row borders, the per-language chip, the empty state, the
rail footer note, and the fixed 168 pt rail (content-sized instead).
