# HandySpeak

HandySpeak is a bilingual/multilingual AAC (Augmentative and Alternative
Communication) tablet app that lets non-verbal or speech-impaired children
compose messages and speak them aloud.

## Language

**Language pair**:
The two languages (base + second) a parent selects in Settings; the child's
top-bar toggle always shows exactly these two, base first. Distinct from the
full set of supported languages (EN/CS/UK), which is always three.
_Avoid_: supported languages, active languages

**Base language**:
The first-position language in a language pair — the app launches into it and
it appears left in the top-bar toggle. Carries no other special meaning:
switching to it works identically to switching to the second language.
_Avoid_: primary language, default language

**Second language**:
The other language in a language pair. A pair is always exactly two
languages; this is the one the child can flip to alongside the base.
_Avoid_: secondary language, alt language

**Voice-pack warning**:
A per-language, display-only notice in Settings shown when no installed TTS
voice matches a language pair slot. Checked when Settings opens and on manual
refresh; never blocks composing or Speak (the engine falls back to a default
voice).
_Avoid_: voice missing, TTS warning
