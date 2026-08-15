\# HandySpeak — Handoff Addendum 03

\## Ukrainian locale (ЙЦУКЕН keyboard + full UI) \& the base/second language pair



This document extends the original HandySpeak handoff package and Addenda 01–02.

It specifies the approved features validated in the POC (`tablet.jsx`,

`i18n.jsx`, `styles.css`, plus new design-canvas artboards in `app.jsx` —

section "Ukrainian · ЙЦУКЕН + language pair").



\## Context



Since Addendum 02, the POC gained a third locale (Ukrainian, `uk` / `uk-UA`)

and replaced the hardcoded EN ⇄ CZ toggle with a parent-configured \*\*language

pair\*\* (base + second). Everything else — modes, math board, message-bar

workspaces, word-tile editing, mood voices, all Addendum 01/02 behavior — is

unchanged.



The new design was diffed against the old prototype — it changes nothing

beyond these 3 features: \*\*(1) Ukrainian locale (keyboard layout + full UI/

vocabulary translation), (2) parent-chosen base/second language pair driving

the kid toggle, (3) per-language voice-availability warnings in Settings.\*\*

A small accessibility bugfix is bundled (see Bugfixes).



\---



\## Feature 1 — Ukrainian locale (`uk`, BCP-47 `uk-UA`)



\### Why

Ukrainian-speaking children (a large refugee/migrant population in Czech

schools) need the same first-class support as EN/CS: their own keyboard,

symbol words, phrases, UI language, and TTS voice.



\### Setting (location / default)

No new setting of its own — Ukrainian becomes a third option in the language

pickers of Feature 2. Default pair remains EN + CZ, so `uk` is opt-in.



\### Behavior



\*\*Keyboard layout — ЙЦУКЕН, all letters as first-class keys (POC:

`LAYOUTS.uk` in `tablet.jsx`):\*\*



```

1  2  3  4  5  6  7  8  9  0      ← permanent digit row (type: 'num')

й  ц  у  к  е  н  г  ш  щ  з  х  ї   (12)

ф  і  в  а  п  р  о  л  д  ж  є  ґ   (12)

я  ч  с  м  и  т  ь  б  ю  ʼ         (10)

```



Architectural constraints (non-negotiable, AAC rules):

\- \*\*No AltGr / long-press / modifier-hidden letters.\*\* On physical keyboards

&#x20; `ґ` hides behind AltGr and the apostrophe is awkward; here \*\*all 33 letters

&#x20; + the orthographic apostrophe are plain keys\*\*: `ґ` closes row 2, the

&#x20; apostrophe closes row 3. The apostrophe key emits \*\*U+02BC MODIFIER LETTER

&#x20; APOSTROPHE\*\* (`ʼ`), the correct Ukrainian orthographic character — it is a

&#x20; \*letter\*, does not break the whitespace word-tile tokenizer, and must not

&#x20; be substituted with ASCII `'`.

\- \*\*Permanent digit row on top, like English\*\* — Ukrainian rows are 12/12/10,

&#x20; so there is room. Consequently the layout sets `hasNumRow: true` semantics:

&#x20; \*\*no `123` swap key appears\*\* (that key remains Czech-only, per Addendum 02).

\- Shift/uppercase and the "Big letters" parent setting (Addendum 01) work on

&#x20; Cyrillic exactly as on Latin (standard Unicode case mapping — no special

&#x20; code needed, but verify ґ→Ґ, є→Є, і→І, ї→Ї).



\*\*Translations (POC: `i18n.jsx`):\*\*

\- Full `uk` UI string table — every key present in `en`/`cs` exists in `uk`;

&#x20; nothing falls back to English.

\- Full vocabulary maps parallel to Czech: `WORDS\_UK` (symbol tiles + Snap\&Say

&#x20; targets/alternates), `CATS\_UK` (category names), `MOODS\_UK` (mood voices),

&#x20; `PHRASES\_UK` (default My-Phrases). The lookup layer is now table-driven

&#x20; (`WORDS\_BY\_LANG` etc.) — adding a locale means adding maps, not editing

&#x20; resolver code. Follow that shape in production.

\- \*\*Ukrainian plural rules for the word count\*\* (`wordCount` in `i18n.jsx`):

&#x20; 1 слово · 2–4 слова · 5+ слів, with the 11–14 exception

&#x20; (`n%10===1 \&\& n%100!==11` → слово; `n%10 in 2..4 \&\& n%100 not in 12..14` →

&#x20; слова; else слів).

\- Math mode: the mode pill reads \*\*«Лічба»\*\*, the back key \*\*«АБВ»\*\*. The

&#x20; `MATH\_SPEAK` operator map needs a `uk` column — \*\*not present in the POC\*\*

&#x20; (math speech falls back to EN glyph words for uk): plus → «плюс», minus →

&#x20; «мінус», times → «помножити на», divided by → «поділити на», equals →

&#x20; «дорівнює», is less than → «менше ніж», is greater than → «більше ніж».

&#x20; Implement this in production even though the POC omits it.



\*\*TTS:\*\* `LANGS` gains `{ id:'uk', bcp47:'uk-UA', voicePrefix:'uk' }`; the

existing voice-matching logic (utterance lang + prefix-matched installed

voice, mood rate/pitch on top) applies unchanged.



\*\*Prediction:\*\* explicitly out of scope. The POC ships only sentence starters

(`PREDICT\_UK = { '': \['Я','Хочу','Мені'] }`) so the strip isn't empty; typed

words pass through unchanged (the generic non-EN fallback never fabricates

`-ing`/`-ed` suffixes). Do not build a Ukrainian prediction table now.



\### Surfaces affected

\*\*Include:\*\* keyboard board (new `uk` layout), Symbols board + categories,

My Phrases (a third per-language bucket), mood-voice strip, message bar word

count, Settings sheet (all strings), Snap \& Say (labels + recognized-word

translations), TTS, top-bar language toggle (via Feature 2), math-mode pill

label.

\*\*Exclude:\*\* math board glyph keys (language-neutral), math buffer (survives

language switch, per Addendum 02), prediction engine (stub only), stored

phrase data model (already per-language), the "BETA" badge on Snap \& Say

(brand mark, intentionally untranslated).



\---



\## Feature 2 — Base + second language pair (parent setting)



\### Why

With three supported languages, a three-way kid-facing toggle would grow

unbounded and clutter the child's top bar. A child realistically flips between

exactly two languages; the parent picks which two.



\### Setting (location / default)

Settings → \*\*Language\*\* section, replacing the single language list. Two

pickers, each listing all three languages (EN / CZ / UK):

\- \*\*Base language\*\* — default `en`. Shown \*first (left)\* in the top-bar

&#x20; toggle; the board starts in it on launch.

\- \*\*Second language\*\* — default `cs`. The other language the child can flip to.



\### Behavior

\- \*\*Symmetric toggle.\*\* "Base" means nothing more than first-position +

&#x20; launch default. Toggling to either language flips \*everything\* together —

&#x20; UI strings, keyboard layout, symbol words, My Phrases, TTS voice — exactly

&#x20; as the EN⇄CZ toggle always has. There is no UI-language / typing-language

&#x20; split.

\- \*\*The kid-facing top-bar toggle always shows exactly two pills\*\*, base

&#x20; first. It never shows three. (POC: `TopBar` receives `langPair` and renders

&#x20; only that pair.)

\- \*\*base ≠ second always holds.\*\* Selecting the other slot's current language

&#x20; \*\*swaps the pair\*\* (choosing UK as base while UK is second makes the old

&#x20; base the new second) — no error state, no disabled options.

\- If a pair change orphans the active language (it's no longer in the pair),

&#x20; the board \*\*snaps to base\*\*, using the standard language-switch path

&#x20; (sentence buffer clears, math buffer survives — Addendum 02 rules).

\- Language-switch side effects are otherwise unchanged from Addendum 02.



\### Surfaces affected

\*\*Include:\*\* Settings → Language section (two pickers + descriptions),

top-bar toggle, launch-default logic, persisted app settings (store

`baseLang` + `secondLang`; drop the assumption that available languages = the

toggle).

\*\*Exclude:\*\* everything downstream of "active language" — no other surface

knows about the pair, only about the active language. Single-language mode

(hiding the toggle entirely) is deferred, see below.



\---



\## Feature 3 — Per-language voice-pack warnings in Settings



\### Why

A missing TTS voice pack is per-language: EN may be installed while UK is not.

One generic warning couldn't tell the parent \*which\* language needs a pack.



\### Setting (location / default)

Not a setting — an automatic inline warning. Lives directly \*\*under each

language picker\*\* (base and second separately) in Settings → Language.



\### Behavior

\- Voice availability is checked \*\*independently per slot\*\* (POC: two

&#x20; `useVoiceAvailable(voicePrefix)` calls in `SettingsSheet`), re-checked when

&#x20; the device's voice list changes (`voiceschanged`).

\- When a slot's language has no installed voice matching its prefix, that

&#x20; slot shows the warning \*\*naming the language\*\*: i18n key

&#x20; `voiceMissingNamed` with `{lang}` substituted by the language's display

&#x20; name (e.g. "No Українська voice on this tablet yet…").

\- The warning renders in the \*\*current UI language\*\* (like all of Settings) —

&#x20; it names the missing language, it is not written in it.

\- Display-only: composing and Speak still work (the engine falls back to a

&#x20; default voice); nothing is blocked.



\### Surfaces affected

\*\*Include:\*\* Settings → Language section only.

\*\*Exclude:\*\* the kid-facing board (no warnings there), TTS behavior (fallback

unchanged), the old single `voiceMissing` warning location (removed —

superseded by the per-slot warnings).



\---



\## i18n — new/changed keys (existing locales) 



| key | EN | CS |

|---|---|---|

| `setLanguageDesc` | Pick the two languages shown in the top bar. Tapping one switches the whole board and the speaking voice. | Vyber dva jazyky zobrazené v horní liště. Ťuknutí přepne celou tabulku i mluvící hlas. |

| `setBaseLang` | Base language | Základní jazyk |

| `setBaseLangDesc` | Shown first in the top bar; the board starts here. | V horní liště je první; tabulka jím začíná. |

| `setSecondLang` | Second language | Druhý jazyk |

| `setSecondLangDesc` | The other language the child can flip to. | Druhý jazyk, na který dítě může přepnout. |

| `voiceMissingNamed` | No {lang} voice on this tablet yet — add one in your device’s speech settings for the best pronunciation. | V tabletu zatím není hlas pro jazyk {lang} — přidej ho v nastavení řeči zařízení pro nejlepší výslovnost. |

| `voiceMissing` (generalized) | No voice for this language on the tablet yet — … | V tabletu zatím není hlas pro tento jazyk — … |

| `closeLabel` (a11y, new) | Close | Zavřít |

| `captureLabel` (a11y, new) | Capture | Vyfotit |



Ukrainian values for these keys, plus the \*\*complete `uk` UI table,

`WORDS\_UK`, `CATS\_UK`, `MOODS\_UK`, `PHRASES\_UK`\*\*, are in

`POC-source/i18n.jsx` — that file is the source of truth; do not re-translate.



`LANGS` display data: `{ id:'uk', short:'UK', name:'Українська', bcp47:'uk-UA' }`.



\---



\## Bugfixes bundled in this addendum



\- \*\*Hardcoded English accessibility strings\*\* (separate from the features

&#x20; above): the top-bar toggle's `aria-label="Language"`, the Snap \& Say close

&#x20; button's `title`/`aria-label` ("Close"), and the shutter's `aria-label`

&#x20; ("Capture") were untranslated. Now localized via `t()` (`setLanguage`,

&#x20; `closeLabel`, `captureLabel`). Affects screen-reader output only.



\---



\## Acceptance criteria



Ukrainian locale:

\- \[ ] `uk` keyboard renders digits 1–0 on top (permanent), then ЙЦУКЕН 12/12/10 with `ґ` last on row 2 and `ʼ` last on row 3; \*\*no `123` key\*\* in the bottom row

\- \[ ] The apostrophe key inserts U+02BC (`ʼ`), and a word containing it (`м’яч` typed as `мʼяч`) stays one word tile

\- \[ ] No letter requires a modifier, long-press, or secondary layer

\- \[ ] With `uk` active, every visible string on every screen (board, Settings, Snap \& Say, message bar word count) is Ukrainian — nothing falls back to English or Czech

\- \[ ] Word count pluralizes correctly: 1 слово, 2 слова, 5 слів, 11 слів, 21 слово, 22 слова

\- \[ ] Symbols tiles, categories, moods, and default My Phrases show Ukrainian labels and are \*\*spoken\*\* in Ukrainian (TTS receives the Ukrainian word, utterance lang `uk-UA`)

\- \[ ] "Big letters" uppercases Cyrillic correctly (ґ→Ґ, є→Є, і→І, ї→Ї)

\- \[ ] Math pill reads «Лічба»; spoken operators use the `uk` MATH\_SPEAK column («дорівнює», not "equals")

\- \[ ] Prediction strip shows only the starter words (Я / Хочу / Мені) and never fabricates suffixes



Language pair:

\- \[ ] Settings → Language shows Base + Second pickers, each offering EN / CZ / UK

\- \[ ] Top-bar toggle shows exactly the chosen pair, base first — never three pills

\- \[ ] Selecting the other slot's language swaps the pair (never equal, never blocked)

\- \[ ] App launches in the base language

\- \[ ] If a pair change removes the active language, the board snaps to base; sentence buffer clears, math buffer survives (Addendum 02 rules)

\- \[ ] Toggling is fully symmetric: either pill flips UI + keyboard + symbols + phrases + TTS together



Voice warnings:

\- \[ ] With the UK voice pack absent and EN present, a warning appears \*\*only under the slot set to Ukrainian\*\*, naming «Українська»

\- \[ ] Both warnings can appear simultaneously (both packs missing); neither appears when both are installed

\- \[ ] The warning text is in the current UI language and updates when voices are installed (`voiceschanged`)

\- \[ ] Speak still works (fallback voice) while the warning shows



Bugfix:

\- \[ ] Toggle group, Snap \& Say close, and shutter expose localized `aria-label`/`title` in all three languages



\---



\## Deferred (do NOT implement now)



\- \*\*Single-language mode\*\* — allowing the parent to pick just one language and

&#x20; hide the kid toggle entirely. Agreed as desirable; explicitly out of scope

&#x20; for this addendum.

\- \*\*Ukrainian prediction table\*\* — beyond the sentence-starter stub.

\- \*\*More locales / >2-language pairs\*\* — the pair model is deliberately capped

&#x20; at two kid-facing languages.

\- \*\*Localizing the "BETA" badge\*\* — treated as a brand mark for now.

\- \*\*UI-language vs. typing-language split\*\* (base = parent UI, second = child

&#x20; composing language) — considered and rejected in favor of the symmetric

&#x20; toggle; do not build.



