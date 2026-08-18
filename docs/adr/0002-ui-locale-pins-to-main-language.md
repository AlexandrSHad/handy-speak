# UI language pins to the main language

Today the app locale follows the *active* language — flipping the child's
top-bar toggle rebuilds every UI string, so a Czech-speaking parent sees
Settings and helper text in English the moment the kid explores the EN board.
We decided the UI language is, by definition, always the main language; the
active language flips only the board (keyboard layout, symbols, phrases) and
the TTS voice. Rationale: parents and kids always see chrome in their
language, and a fixed set of UI words is more learnable for this audience
than words that change mid-session. `MaterialApp` therefore no longer
rebuilds on toggle (locale only moves with a main-language change).

Considered and deferred: localizing individual child-facing surfaces (Speak
button label, message-bar placeholder, mode tabs) to the active language as
a parent-configurable option. Deliberately not built now; if added later, it
extends this decision surface-by-surface rather than reversing it.
