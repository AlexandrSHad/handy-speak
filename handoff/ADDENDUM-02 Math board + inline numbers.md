# HandySpeak — Handoff Addendum 02
## Math board (a third input mode) + inline numbers on the keyboard

This document extends the original HandySpeak handoff package and Addendum 01.
It specifies one approved feature area validated in the POC (`tablet.jsx`,
`i18n.jsx`, `styles.css`, plus the design-canvas artboards in `app.jsx`).
Implement it in the production codebase following the patterns already
established by existing input modes (*Keyboard*, *Symbols*) and parent settings.

Everything here MUST behave identically for English and Czech.

### Guiding principle — this is a *voice*, not a calculator
HandySpeak never computes. The math board lets a child **compose and speak** a
simple problem the same way every other board composes a message. Pressing
**Speak** voices the whole problem in words ("three plus four equals seven");
the board itself does no arithmetic, shows no result, and has no `=`-evaluates
behavior. Keep this framing — it drives every decision below.

---

## Feature 1 — Math mode (third input board)

### Why
Children need to participate in math class and to *say* number relationships
out loud ("8 is greater than 5"), which the letter keyboard and pictograms
cannot express cleanly.

### Entry points
- A **third mode pill** in the top mode-toggle, after Keyboard and Symbols.
  - Icon: a small tablet/pad glyph (POC: `Icon.math`).
  - Label: localized — **"Math"** (EN) / **"Počítání"** (CS). The label is a
    real translated string, not the literal "123".
- Selecting it swaps the input area to the math board, exactly like switching
  to Symbols. It is a peer mode, not a modal overlay.

### The board layout (approved final)
One aligned grid, **four equal-width columns × five rows**, calculator digit
order (7-8-9 on top). POC: `.math-grid` with `grid-template-columns: repeat(4, 1fr)`.

```
   7   8   9   ÷
   4   5   6   ×
   1   2   3   −
   0 (span 2)  .   +
   <   >   =   ⌫
```

- **Digits 0–9 and the decimal point** — neutral ink keys. `0` spans the two
  bottom-left cells (POC: `.key.num`, `.zero { grid-column: span 2 }`).
- **Operators `÷ × − +`** — the right-hand column, teal tint, one per row
  aligned with the digit rows (POC: `.key.op`). Use the true typographic
  glyphs `×` `÷` `−` (multiplication, division, minus signs), **not** ASCII
  `x`, `/`, `-`.
- **Comparison `< > =`** — the bottom row, violet tint, equal weight
  (POC: `.key.rel`). `=` is a normal peer key here — **not** a colored,
  enlarged, or otherwise privileged "calculator equals". It sits in the third
  column.
- **Backspace `⌫`** — bottom-right corner cell, neutral/grey with the delete
  icon (POC: `.key.bksp`), deliberately styled as an *action* not a symbol,
  and placed in the corner to mirror the keyboard's own bottom-right delete
  key. Deletes one glyph (see tokenizer rules below).

There is **no** in-board "ABC / back to keyboard" key — the child leaves Math
the same way they leave any mode: via the top mode-toggle.

### How keys compose text — spacing tokenizer (critical, reuses existing code)
The message bar already tokenizes text on whitespace into editable word tiles.
The math board writes into that same buffer using spacing rules so that:
- **Consecutive digits group into ONE tile.** Typing `4` then `2` yields the
  single tile `42`, which the bar/TTS reads as "forty-two" (POC:
  `mathAppendDigit` — a digit joins the trailing number if the text currently
  ends in a digit or `.`; otherwise it starts a fresh number).
- **Every operator and comparison sign is its OWN tile**, space-delimited
  (POC: `mathAppendOp` — trims trailing space, appends ` <sign> `). So
  `3 + 4 = 7` is five tiles: `3` `+` `4` `=` `7`.
- **Backspace** removes one glyph: it trims a digit off the trailing number,
  or drops a whole sign (POC: `mathBackspace`).

Because the tiles are ordinary whitespace tokens, **all existing word-tile
editing affordances work unchanged** — the child can swipe-remove, tap-to-x,
drag-reorder, and re-select math tiles exactly like sentence words. Do not
build a separate editor for math.

### Speech — glyph → spoken words (critical)
TTS engines pronounce `× ÷ = < >` unreliably. Before the composed string is
handed to the existing speech engine, translate each operator/comparison glyph
to its spoken words for the current language; numbers pass through untouched
(the engine reads "42" correctly). POC: `mathSpeak(text, lang)` applied only
when `mode === 'math'`; the existing mood rate/pitch and voice selection then
apply on top, unchanged.

Spoken map (POC `MATH_SPEAK`):

| glyph | EN | CS |
|---|---|---|
| `+` | plus | plus |
| `−` | minus | mínus |
| `×` | times | krát |
| `÷` | divided by | děleno |
| `=` | equals | rovná se |
| `<` | is less than | je menší než |
| `>` | is greater than | je větší než |

Example: `12 × 5 =` speaks "twelve times five equals" / "dvanáct krát pět
rovná se". A digit typed inline in a *sentence* (see Feature 2) still speaks
naturally as "two" because `mathSpeak` is only applied in math mode.

---

## Feature 2 — Inline numbers on the keyboard

### Why
Children also use numbers *inside sentences* ("I need 2 candies"). They must be
able to drop a digit into a sentence without leaving the letter keyboard.

### English — already solved
The English keyboard already has a permanent top digit row (`1`…`0`). Nothing
new is required; typed digits flow into the sentence normally.

### Czech — reveal-on-demand row swap
The Czech keyboard has **no room** for a permanent digit row: its top row is
15 diacritics (á č ď é ě í ň ó ř š ť ú ů ý ž). So digits are revealed on demand:

- A **`123` key** sits in the bottom modifier row (POC: replaces the old,
  dead `?123` key). It appears **only** on layouts that lack a permanent digit
  row — i.e. Czech shows it, English does not (POC gate: `hasNumRow`).
- Tapping it **swaps the diacritics row in place** into a `0–9` digit row —
  no motion, nothing slides over the letters, nothing is covered
  (POC: `numOpen` state; the row with `type: 'accent'` renders digits instead).
- It is a **toggle that stays open** until pressed again — no pop-up overlay,
  no "Done" button. The key's own label flips: it reads **`123`** when letters
  are showing and **`ABC`** when digits are showing.
- Digits inserted this way are ordinary sentence characters (they speak as
  "two", group into multi-digit tiles via the same whitespace tokenizer).

> Design note: an earlier "slide-in strip above the letters" variant (Option A)
> was explored and **rejected** in favor of the in-place swap (calmer, zero
> motion, nothing occluded). Do not implement the slide-in strip.

The full **Math board is a separate destination** (the top pill). The bottom
`123` key is for *inline digits in a sentence only*; it does not open the math
board and does not expose operators or comparisons.

---

## Feature 3 — Two message-bar workspaces (non-destructive mode switching)

### Why
Keyboard + Symbols compose a *sentence*; Math composes a *problem*. If a typed
sentence survived a switch into Math, it looked wrong stacked above the numpad;
and clearing it on switch risked destroying effortful work on an accidental tap.

### Behavior (approved)
- The message bar is backed by **two buffers**: a **sentence** buffer shared by
  Keyboard and Symbols, and a separate **math** buffer. The visible/active
  buffer is derived from the current mode (POC: `sentenceText` / `mathText`;
  `text = mode==='math' ? mathText : sentenceText`, and `setText` routes to the
  matching setter). Every existing handler keeps using `text` / `setText`.
- Switching **Keyboard/Symbols → Math** shows the math workspace (its own
  content — empty on first entry). The sentence is **set aside, not erased**.
- Switching **Math → Keyboard/Symbols** restores the sentence exactly as left.
- **Math remembers its last problem** until the child clears it.
- Nothing is destroyed in either direction; a sentence never appears on the
  numpad.
- **Language switch** clears **only the sentence** buffer (free-typed prose is
  language-bound and can't be auto-translated). The math buffer is glyphs/digits
  and is **language-neutral, so it survives** a language switch
  (POC: lang-switch callback calls `setSentenceText('')` only).

Keyboard ⇄ Symbols continue to **share** one buffer (you may start a sentence
by typing and add a pictogram, or vice-versa) — the split is strictly
*sentence* (Keyboard+Symbols) vs *problem* (Math).

---

## i18n strings (add to both locales)

| key | EN | CS |
|---|---|---|
| `math` | Math | Počítání |
| `backspace` | Delete | Smazat |

(`math` labels the mode pill; `backspace` is the aria-label/title on the
in-pad `⌫` key. No other new visible strings — operator/comparison spoken
words live in the `MATH_SPEAK` map above, not the UI string table.)

---

## Acceptance criteria

Math mode:
- [ ] A third pill "Math"/"Počítání" appears after Keyboard and Symbols and switches to the board
- [ ] Grid is 4 equal columns: digits + decimal (neutral), `÷ × − +` column (teal), `< > =` row (violet), `⌫` bottom-right (neutral). `0` spans two cells. `=` is a normal peer, not enlarged/highlighted
- [ ] Operators render as true glyphs `× ÷ − =` `< >`, not `x / - `
- [ ] Consecutive digits form one tile (`4`,`2` → `42` → speaks "forty-two"); each operator/comparison is its own tile
- [ ] Math tiles support the same swipe/tap-x/drag editing as sentence words
- [ ] Speak voices operators/comparisons as words in the active language ("times"/"krát", "equals"/"rovná se", "is greater than"/"je větší než") with the current mood voice applied
- [ ] `⌫` deletes one glyph (a digit off a number, or a whole sign)

Inline numbers:
- [ ] English keyboard keeps its permanent digit row and shows NO `123` key
- [ ] Czech keyboard shows a `123` key in the bottom row; tapping swaps the diacritics row in place to `0–9` with no motion/overlay
- [ ] The key label toggles `123` ⇄ `ABC`; the row stays swapped until pressed again
- [ ] Digits typed inline speak naturally ("two", not operator words) and group into multi-digit tiles

Workspaces:
- [ ] Keyboard→Math shows an empty (or last-used) math workspace; the sentence is preserved
- [ ] Math→Keyboard restores the sentence intact
- [ ] Math remembers its last problem until cleared
- [ ] Keyboard ⇄ Symbols share one buffer
- [ ] Language switch clears only the sentence; a math problem survives the switch

Parity & persistence:
- [ ] All of the above behaves identically in EN and CS (incl. Czech diacritics row swap)

## Deferred (do NOT implement now)
- **Advanced Math mode** — the home for `≠`, `≤`, `≥`, and any richer operators.
  `≠ ≤ ≥` were intentionally removed from the basic board (no compelling
  early-years use); they belong here later.
- **Speak-while-typing (per-key echo)** — removed from the POC. If revived, do
  NOT echo the single key pressed (it says "one, two" for 12). The approved
  future approach is to **re-speak the whole running number** on each digit
  (`1`→"one", `2`→"twelve", `5`→"one hundred twenty-five"), modeling place
  value, with operators echoing as their word. Parent-optional, default OFF.
- **Cross-linking the Symbols "Numbers" pictogram category** (one/two/more/less)
  to the math board — quantity *words* and *symbolic arithmetic* are kept as
  separate jobs for now.
