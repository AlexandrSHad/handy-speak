# Settings becomes a categorised dialog

Status: accepted. The geometry experiment left open by the first revision of
this ADR is now resolved (see "The geometry, and how it changed" below);
nothing in this ADR is open.

Settings before this change is a modal bottom sheet at `heightFactor: 0.92`
with 24 px side margins and top-only rounded corners — a sheet wearing dialog
margins, running square off the bottom edge, with no max width (≈1232 pt wide
on a 1280 pt tablet, so every description line runs the width of the screen).
Its four sections — Language, Voice, Phrases, Accessibility — are stacked in
one `ListView`, so reaching any of them means scrolling past the others. We
decided Settings becomes a **popup dialog divided into three categories**,
navigated by a rail pinned to the left: **Language** (holding a Language set
section and a Voice section), **Phrases**, and **Accessibility**. It is a
fixed 896×624 and presents full-screen when the screen cannot frame it with
at least `AppTokens.s24` of margin on every side (width < 944 or height <
672) — two states, never an intermediate shrink-to-fit, because a size that
is neither fixed nor full is the one that looks wrong. It always opens on
Language, every change still applies and persists instantly with no Save
button, and it dismisses by scrim, back, or the header X.

Every setting in the app is a parent setting. We deliberately did **not**
introduce a parent/child tier or any gate — no PIN, no long-press — even
though the settings gear sits one unguarded tap away in the child's top bar.
A gate carries its own recovery problem (a parent who forgets the PIN bricks
the app for the family), and the intended long-term answer is a separate
parent companion app rather than a lock on this surface. The entry point is
unchanged, so a gate can be added there later without moving anything. One
consequence lands in the copy: `settingsPhrases` reads "Parent · Phrases"
today, and that prefix models exactly the tier this ADR says does not exist.
It is edited in place to plain "Phrases" rather than promoted to a category
label unchanged.

## The geometry, and how it changed

The first revision of this ADR fixed the dialog at 1040×704 and held itself
open pending a visual comparison against an always-full-screen variant. That
comparison was never produced by the design session. It was run afterwards
against the delivered mockup, and it showed the premise was wrong: at the
1280×800 reference tablet, a 1040×704 dialog leaves a 120 pt side band and a
48 pt top/bottom band, and under the scrim neither the board nor the top bar
is legible in it. "The child's board stays visible" — the reason this ADR
gave for rejecting always-full-screen — was not something 1040×704 delivered.

So the dialog shrank instead of changing kind. At **896×624** the same
tablet yields 192 pt at the sides and 88 pt top and bottom, which is enough
band for the board to actually read as present behind the scrim. It also
lowers the breakpoint to 944×672, so fewer devices fall through to the
full-screen presentation than would have at 1040×704.

The 896×624 figure is confirmed against the built app before this ADR is
treated as final; it was chosen from a mockup, and a mockup is evidence about
composition, not about Flutter's layout.

## Consequences

- **Live board preview is abandoned.** Before this change a parent changes
  the language set and watches the board react behind the sheet. That is a
  real, existing affordance and we are giving it up deliberately: watching
  the app rebuild underneath is closer to unsettling than useful, and it was
  the only thing arguing for a surface that keeps the board visible.
- **The app gains its first dialog idiom and its first breakpoint.** There is
  no `showDialog` anywhere in `lib/` and no breakpoint, max-width or
  screen-size constant either — the only size-aware widget in the app is the
  symbol board's `LayoutBuilder`. Both become theme-level concerns: the
  dialog size, the breakpoint and the content measure cap join `AppTokens`,
  and the chrome becomes a `DialogTheme` in `AppTheme`, not one-off constants
  in a widget.
- **Content is capped at a 640 pt measure** inside the pane, left-aligned.
  This is what actually fixes the full-width-text complaint that motivated
  the redesign. At 896 wide it barely bites; in the full-screen presentation,
  where the pane is widest, it does all the work.
- **The rail is sized to its content, not to a fixed width.** An earlier
  draft pinned it at 168 pt to match the symbol board's rail, and used that
  parity as an argument for a rail over top tabs. Measurement killed the
  parity: at text scale 1.3 the Ukrainian and English Phrases labels exceed
  the text width a 168 pt rail affords, so a fixed rail would have wrapped
  the very labels whose truncation was the reason tabs lost. A content-sized
  rail cannot wrap. The two rails no longer match, and no shared token
  enforces anything.
- **The rail is unbounded.** At extreme system text scales it can grow to
  consume an arbitrary share of the dialog. Accepted deliberately rather than
  clamped, on the grounds that the alternative reintroduces wrapping.
- **Narrow widths are an accepted gap.** The rail survives in both
  presentations, so iPad Split View / Slide Over widths are unsupported. The
  app is landscape-locked and iOS is deferred, so this is documented rather
  than built for.
- **The full-screen presentation must be a borderless dialog, not a pushed
  route.** A dialog leaves the board in the widget tree beneath the scrim,
  which several existing tests rely on; an opaque route can push it offstage
  where finders will not see it.
- **Three ARB keys are added, not zero.** An earlier draft claimed the three
  categories reuse `settingsLanguage`, `settingsPhrases` and
  `settingsAccessibility` unchanged and need no new strings. That was wrong
  twice: the Language category now contains a section that needs its own
  title (`settingsLanguageSet`, matching the glossary's *language set*), and
  the Phrases and Accessibility categories each carry a subtitle
  (`settingsPhrasesDesc`, `settingsAccessibilityDesc`). Nine entries across
  the three locales, plus `settingsPhrases` edited in place.
- **Accessibility is sparse and stays sparse.** It holds exactly three
  toggles — Big letters, Haptics, Dark mode — in a 624 pt-tall dialog. Its
  new subtitle is the only mitigation. Filling it would have meant inventing
  settings, which is how the design mockup handled it: that mockup shows
  eight rows, four of which (switch scanning, and toggles for word-block
  gestures) have no counterpart anywhere in `lib/`.
- **Language may scroll after all.** An earlier draft promised only Phrases
  scrolls. With both voice-pack warnings and the unsupported-device-language
  banner raised at once, Language exceeds the pane — a state that was already
  borderline at 1040×704. Accepted: it is the rarest state and the one where
  there is genuinely more to read.
- **Voice-pack warnings are only visible inside Language.** Since the dialog
  always opens there, a parent sees them on arrival. The residual case — the
  TTS engine reaching `ready` up to ~16 s after open, raising a banner in a
  category the parent has since left — is accepted and self-corrects on the
  next open.
- **"Category" needed disambiguating before this shipped.** The symbol board
  has called its eight word groups categories since the initial
  implementation, unqualified, in `categories.dart` / `kCategories` /
  `_CategoryRail`. This ADR claims the bare word for the Settings sense, so
  the board's identifiers are renamed to `symbol_categories.dart` /
  `kSymbolCategories` / `_SymbolCategoryRail` in a separate prep commit, and
  `CONTEXT.md` gains a **Symbol category** entry. Without that the codebase
  would have two unqualified `Category` concepts in adjacent files — the same
  collision that disqualified "tabs" below.
- **Three test suites change.** `addendum01` scrolls "the first `ListView`
  inside the `BottomSheet`" to reach every toggle, `addendum03` expects both
  language dropdowns co-visible, and `addendum04`'s height-parity test drags
  a single list until the language dropdown *and* the phrase `TextField` are
  measurable together — impossible once they live in different categories, so
  it measures across two category visits instead. `addendum03` needs the
  least work: both dropdowns land in the same category. The assertions stay;
  only the helpers that reach the controls are rewritten.

## Considered and rejected

- **Keeping the bottom sheet, marginless or taller.** Cheapest option, but it
  addresses neither grouping nor the full-width text measure, which are the
  actual complaints.
- **Always full-screen.** Genuinely attractive — it deletes the breakpoint,
  the second layout state, and the scrim semantics entirely. It was rejected
  once as a default, then re-examined when the comparison above showed
  1040×704 was not buying the visible board it claimed to. Rejected again,
  but on a narrower basis: a full-screen takeover is a heavy context switch
  for a parent making a ten-second change, and at 896×624 the board genuinely
  is visible around the dialog, so the thing full-screen would have cost is
  now actually delivered.
- **Fixed at 1040×704.** The original figure. Superseded because it framed
  the dialog in a band too thin to show anything.
- **Top tabs instead of a left rail.** Rejected twice over: the Czech and
  Ukrainian category labels (*Přístupnost*, *Доступність*) truncate as
  horizontal tabs at text scale 1.3, which the existing suites explicitly
  pin, and "tabs" already names the board's Keyboard/Symbols/Math toggle in
  this codebase and its planning documents.
- **A fourth category for Speech/Voice.** It would ship containing exactly
  one permanently-disabled row (Mood voices, off by design for the POC) — a
  category a parent opens to find nothing they can do. Voice stays a section
  under Language until speech rate and pitch actually land, then promotes.
- **A Save/Done button.** A full-screen surface invites one, but it would
  introduce dirty state, a discard prompt, and a way to lose edits. Instant
  apply means dismissal can never lose a setting — only half-typed text in
  the add-phrase field, which is not worth a confirmation dialog. The design
  proposed a permanent "Changes save as you make them" note in the rail to
  explain the absence; rejected, because instant apply has been the behaviour
  since the sheet shipped and a standing line of chrome costs more than the
  absence does.
