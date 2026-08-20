# HandySpeak

HandySpeak is a multilingual AAC (Augmentative and Alternative Communication)
tablet app that lets non-verbal or speech-impaired children compose messages
and speak them aloud.

## Language

**Main language**:
The first language in the language set — the app's default board language,
shown first in the top-bar toggle; the UI language always equals it.
Renamed from "base language" (ADDENDUM-04); "base" wording is gone.
_Avoid_: base language, primary language, default language

**Second language**:
The optional other language in the language set. When configured, the
child's top-bar toggle shows main + second; when absent, the app is
single-language and the toggle is hidden.
_Avoid_: secondary language, alt language

**Language set**:
The parent's configuration: the main language plus optionally one second
language. The child's top-bar toggle shows exactly the configured languages,
never all supported languages (EN/CS/UK).
_Avoid_: language pair, supported languages, active languages

**Active language**:
The language the child selects via the top-bar toggle; drives the board
(keyboard layout, symbols, phrases) and the TTS voice only. Always one of
the configured languages; snaps back to main if a configuration change
orphans it.
_Avoid_: selected language, current language

**UI language**:
The language all app chrome renders in; by definition always the main
language. Never changed by the language switcher.
_Avoid_: app language, chrome language, "UI follows active language"

**Voice-pack warning**:
A per-language, display-only notice in Settings shown when no installed TTS
voice matches a language set slot. Checked when Settings opens and on manual
refresh; never blocks composing or Speak (the engine falls back to a default
voice).
_Avoid_: voice missing, TTS warning

## Settings

**Settings dialog**:
The single surface where a parent adjusts the app. A popup dialog by
nature; on screens too small to frame it, it presents full-screen — that
is a change of presentation, never a change of identity, so it is called
the Settings dialog in both. Divided into categories.
_Avoid_: settings sheet, settings screen, settings page, settings modal

**Setting**:
One parent-controlled preference. Every setting in the app is a parent
setting — there is no child-facing settings tier and no access control on
reaching them. A future parent companion app may take some over; until
then the distinction does not exist and must not be modelled.
_Avoid_: parent setting, child setting, advanced setting

**Category**:
A top-level division of the Settings dialog. Exactly one category is
visible at a time; the others are reached by an explicit navigation
choice. A category groups one or more sections around a single concern.
Unqualified "category" in prose means this one; the board's word groups
are symbol categories. Code qualifies both (`SettingsCategory`,
`SymbolCategory`).
_Avoid_: tab, page, screen

**Section**:
A titled group of related settings inside a category, with an optional
explanatory subtitle. Sections never nest and are never navigable — they
scroll with the category that contains them.
_Avoid_: group, panel, block

## Board

**Symbol category**:
One of the eight fixed groups a pictogram belongs to on the symbol board
(Feelings, Food, School, Family, Activities, Places, Numbers, Hello),
selected one at a time from the board's left rail. A child-facing concept,
unrelated to the Settings dialog's categories.
_Avoid_: category (unqualified), pictogram group, symbol group, topic
