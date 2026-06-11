# HandySpeak — Handoff Addendum 01
## Two new parent settings: "Big letters" (uppercase-only) and optional "My phrases" strip

This document extends the original HandySpeak handoff package. It specifies two
approved features that were validated in the POC (`tablet.jsx`, `i18n.jsx`,
`styles.css` — see "POC reference" notes throughout). Implement them in the
production codebase following the patterns already established by existing
parent settings (e.g. *Mood voices*, *Haptic feedback*).

Both features MUST behave identically for English and Czech.

---

## Feature 1 — Big letters (uppercase-only mode)

### Why
Some children cannot yet recognize lowercase letters (emergent readers,
dyslexia, developmental delays). Capitals are more visually distinct
(no b/d/p/q mirroring, no i/l ambiguity). This mode shows every letter the
child reads as a capital and prevents switching to lowercase.

### Setting
- Location: **Settings → Accessibility**, first toggle in the section.
- Default: **OFF**.
- Persisted like all other parent settings.

### Behavior — display-only transform (critical)
- Stored text, pinned phrases, prediction insertions, and TTS input keep
  their normal casing. Uppercasing happens ONLY at render time.
- Rationale: toggling the setting off must instantly restore normal display
  with zero data migration, and TTS engines must never receive ALL-CAPS text
  (some engines spell out or stress all-caps words).
- Implementation: a single modifier class on the app root
  (POC: `.upper-only` on `.tablet`) plus CSS `text-transform: uppercase`
  on content surfaces. Do NOT uppercase strings in JS.

### Surfaces to uppercase — CONTENT ONLY
Uppercase exactly these (everything the child decodes letter-by-letter):
1. Keyboard key labels (letters; digits/punctuation unaffected)
2. Prediction bar suggestions — display "WANT", **insert "want"**
3. Word tiles in the message bar, the message placeholder, and the
   undo chip ("Bring back …")
4. Pictogram labels and category names on the symbol board
5. Phrase chips in the "My phrases" strip
6. Snap & Say: detected word, alternative chips, demo pills, and
   "just snapped" recent items

Do NOT uppercase UI chrome: Speak button, mode toggle, mood strip,
settings sheet, section labels, etc.

POC reference selector list (`styles.css`, "Big letters" block):
`.key, .prediction, .wblock, .wb-placeholder, .wb-undo, .pictogram .label,
.cat, .phrase-chip, .recent-item, .demo-pill, .alt-chip, .result-card .word`

### Shift key
- The Shift key **stays in its place** in the layout (removing it breaks the
  familiar keyboard silhouette). Same icon.
- It is rendered **disabled**: standard dimmed look (POC: `opacity: .35`,
  `cursor: default`, no hover/pressed states), taps do nothing — no tooltip,
  no animation, no haptic.
- Internal shift state must be treated as OFF while the mode is active
  (POC: `effShift = shift && !upperOnly`), so key presses insert lowercase
  characters even if shift was on when the mode was enabled.
- Keyboard layout rework (repurposing the inert Shift) is **deferred** — do
  not redesign the bottom row.

### Czech parity
- `text-transform: uppercase` must uppercase diacritics correctly
  (á → Á, č → Č, ř → Ř …). Native CSS does; if any surface uppercases in
  code instead, use locale-aware `toLocaleUpperCase('cs')` — but prefer CSS.
- The Czech diacritics key row behaves exactly like letter keys.
- Czech predictions (e.g. "chci") display uppercase, insert lowercase.

---

## Feature 2 — "My phrases" strip optional

### Why
The phrase strip is text-only. For pre-readers it is a row of eight
unreadable buttons wasting vertical space.

### Setting
- Location: **Settings → My phrases section**, as a master toggle at the
  TOP of the section, above the pinned-phrase editor.
- Label: "Show phrase shortcuts". Default: **ON**.

### Behavior
- OFF → the phrase strip is removed from the board entirely (not collapsed,
  not greyed out).
- The freed vertical space goes to the input area:
  - Keyboard mode: key rows stretch taller to fill the space
    (POC: `.no-phrases .kb-row { flex: 1; }`).
  - Symbol mode: pictogram tiles grow (the grid already uses
    `grid-auto-rows: 1fr` — verify it fills the taller area).
- The pinned-phrase editor in Settings **remains visible and fully
  editable** while the strip is hidden (parents curate ahead of time).
  Show a small note under the toggle when OFF — see i18n key
  `setPhrasesHiddenNote`. A redesign of this settings section is
  **deferred**.

---

## i18n strings (add to both locales)

| key | EN | CS |
|---|---|---|
| `setUpperName` | Big letters | Velká písmena |
| `setUpperDesc` | Show every letter as a capital and lock the shift key. Helps kids who don't read lowercase yet — speech is unchanged. | Všechna písmena se zobrazí jako velká a klávesa shift se uzamkne. Pomáhá dětem, které ještě nečtou malá písmena — řeč se nemění. |
| `setShowPhrasesName` | Show phrase shortcuts | Zobrazit lištu frází |
| `setShowPhrasesDesc` | The quick-phrase strip above the keyboard. Turn off for kids who don't read yet — keys and symbols grow bigger. | Lišta rychlých frází nad klávesnicí. Vypni pro děti, které ještě nečtou — klávesy a symboly se zvětší. |
| `setPhrasesHiddenNote` | Hidden on the board — phrases stay saved here and come back when you switch this on. | Na tabulce skryto — fráze tu zůstávají uložené a vrátí se po zapnutí. |

---

## Bugfix included in this addendum

Settings toggle switches were squashed when a row's description text ran
long (flexbox shrinking the fixed-size switch). Fix: the switch control
must never shrink — `flex: 0 0 auto` on the switch element (POC:
`.switch` in `styles.css`).

---

## Acceptance criteria

Big letters:
- [ ] Toggle ON: every surface in the "content only" list renders uppercase, in both EN and CS (including Á Č Ď É Ě Í Ň Ó Ř Š Ť Ú Ů Ý Ž)
- [ ] UI chrome (Speak, mode toggle, mood strip, settings) is NOT uppercased
- [ ] Shift key visible, dimmed, inert; no pressed state possible
- [ ] Typed characters are stored lowercase; tapping a prediction shown as "WANT" inserts "want"
- [ ] TTS receives normal-cased text (verify spoken output is unchanged vs. mode OFF)
- [ ] Toggle OFF: display returns to normal casing instantly, message intact
- [ ] Switching EN ⇄ CZ while ON keeps the mode active

Phrases optional:
- [ ] Toggle OFF: strip gone; keys taller in keyboard mode; tiles larger in symbol mode; no blank band where the strip was
- [ ] Pinned-phrase editor still works while hidden (add / pin / unpin / remove), with the "hidden" note shown
- [ ] Toggle ON: strip returns with all phrases and pin order intact

Both:
- [ ] Settings toggles render at full size regardless of description length
- [ ] Both settings are independent; any of the 4 combinations works
- [ ] Both settings persist across app restarts (per existing settings persistence)

## Deferred (do NOT implement now)
- Keyboard layout rework for uppercase mode (repurposing the inert Shift key)
- "My phrases" settings section redesign
- Profiles/presets (e.g. "pre-reader" = Big letters ON + phrases OFF)
