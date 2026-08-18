# Design Handoff — ADDENDUM-04: Main Language & Language Set (UI/UX only)

You are designing the user-facing surfaces for a planned feature
(ADDENDUM-04) of HandySpeak. The domain model and interaction logic are
**settled** — your job is presentation: layout, states, and copy. Read
`CONTEXT.md` (glossary — use these exact terms), `CLAUDE.md` (project
context), and `docs/adr/0002-ui-locale-pins-to-main-language.md` before
starting.

## Non-negotiables (do not redesign or rename)

- Terminology per `CONTEXT.md`: **main language**, **second language**
  (optional), **language set**, **active language**, **UI language**.
  "Base language" wording is gone everywhere, including UI copy.
- UI language **always equals the main language** (ADR-0002). The child's
  language toggle changes only the board (keyboard, symbols, phrases) and
  the TTS voice. The Speak button label, message-bar placeholder, and mode
  tabs do **not** change language — do not propose that they do.
- Settings pickers are `DropdownButtonFormField`s (already decided).
- The second language is gated by a Switch (enable/disable). Only the Switch
  removes it; picking main = second (or vice versa) swaps the two.
- Single-language mode: the top-bar language toggle is hidden and the space
  reclaimed (you decide what fills it).
- First run defaults to single-language with main = device language;
  unsupported device language falls back to English **plus a persistent
  banner in Settings**. No wizard, no "request a language" email flow —
  both deferred to a later addendum. Do not design them (a rough sketch
  appendix is acceptable but must be clearly marked as future work).

## Project context

- AAC tablet app for non-verbal/speech-impaired children; **parents
  configure, children use**. Landscape-first tablet, Android today (iOS
  later — annotate safe-area concerns if relevant, nothing more).
- Flutter + Material, light and dark themes. Brand color `#1fa567`.
  Theme tokens (use these in mockups as CSS variables):
  `surface` (white / near-black), `surface2` (`#F3F1ED` / dark analogue),
  `surface3`, `ink`, `ink2`, `ink3` (text hierarchy), `primary`
  (`#1fa567`), `primaryPress`, `primarySoft` (selected-state fill),
  `divider`. Radius language: 12–16 px rounded cards.
  See `lib/core/theme.dart` for exact values.
- Localization: EN is the template; CS and UK are full locales. All new copy
  must be proposed in all three.
- Accessibility: motor impairments are the core audience. Child-facing
  surfaces need large forgiving targets. Settings is **parent-facing** —
  standard Material target sizes are acceptable there (this is an explicit,
  documented exception to the child-facing rule).

## Current UI (facts, for fidelity)

- `lib/widgets/top_bar.dart` — Row: brand (icon + name), spacer,
  Keyboard/Symbols mode toggle, spacer, language toggle (2 segments =
  language set), spacer, settings icon button.
- `lib/widgets/settings_sheet.dart` — modal sheet, sections with
  `_SectionTitle` + subtitle rows. The Language section today: two stacked
  full-width button lists (one per language, 3 languages each), a
  refresh-voices icon action, and `NoticeBanner`s ("no installed voice for
  X") under a picker when its language lacks a TTS voice. Other sections:
  Voice, Accessibility, My Phrases — do not touch them.
- `lib/core/app_language.dart` — language endonyms: English, Čeština,
  Українська; short codes EN / CZ / UK.

## Surfaces in scope

1. **Settings → Language section** (primary): two
   `DropdownButtonFormField`s (main, second), the Switch gating the second,
   voice-pack warning banners per slot, unsupported-device-language banner,
   and the section's header/copy.
2. **Top bar, two states**: dual-language (current behavior, new styling
   only if needed) and single-language (toggle hidden, space reclaimed).
3. Nothing else. Speak button, message bar, boards: unchanged.

## States to cover in mockups

| # | State |
|---|-------|
| 1 | Fresh install, single-language (e.g. main = Čeština, no second) |
| 2 | Second language enabled (default fill = first supported ≠ main) |
| 3 | Second language Switch off — the section's disabled/collapsed treatment |
| 4 | Swap moment: second dropdown open, main language excluded from the list |
| 5 | Voice-pack warning under main slot, under second slot, both |
| 6 | Unsupported device language — banner in the Language section |
| 7 | All of the above in light and dark theme |
| 8 | Top bar single vs dual, EN and CS UI renders (UK optional bonus) |

## Open questions your design must answer

- Switch placement: in the "Second language" `_SectionTitle` row, or its own
  row? Disabled-and-grayed vs collapsed-hidden when off?
- Dropdown item anatomy: endonym only? Endonym + English gloss in parens?
  Short code chip? (No flags — flags represent countries, not languages.)
- Where exactly the unsupported-device-language banner sits and its copy
  (mention the fallback that already happened: UI defaulted to English).
- What fills the reclaimed top-bar space in single-language mode — wider
  mode toggle, centered brand, more breathing room? Pick one and justify.
- Copy tone for every new string: section title/desc, "Second language"
  Switch label, dropdown hints, banners. Warm, plain, parent-audience.

## Deliverables

Put everything in `docs/design/addendum-04/`:

1. `mockups.html` — one self-contained file (inline CSS, no external deps,
   no build step) with an in-page control bar to switch: state (1–6),
   light/dark, EN/CS(/UK) UI render. Render as a landscape tablet frame
   (~1280×800) with real aspect for both surfaces (Settings sheet + top bar
   on the board behind it). Use the theme tokens as CSS variables.
2. `spec.md` — your resolutions to the open questions, a state-by-state
   walkthrough, and the proposed strings table (key, EN, CS, UK) ready to
   become ARB entries.

Do not modify anything outside `docs/design/addendum-04/`. No Flutter code,
no pubspec changes, no edits to files listed under Non-negotiables. When
done, summarize your design decisions and their rationale in the spec.
