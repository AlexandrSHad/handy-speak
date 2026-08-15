# Language model widens from binary to N-ary

`AppLanguage`-conditional code was written as binary ternaries
(`lang == AppLanguage.cs ? x : y`) across `app_language.dart`,
`pictograms.dart`, `categories.dart`, `settings_sheet.dart`, and
`speech_service.dart`, with no compiler-enforced exhaustiveness — a missed
site silently falls into the wrong branch instead of failing to compile.
Adding Ukrainian (ADDENDUM-03) is the first time a third language exists, so
we're converting these to exhaustive switch expressions. `pictograms.dart`
and `categories.dart` widen their fixed `en`/`cs` fields to `en`/`cs`/`uk`
(still required constructor fields, not a runtime `Map<AppLanguage, String>`)
— a `Map` literal can silently omit a key and fall back at runtime, while a
required field is a compile error at all ~90 call sites until supplied. The
existing whole-dataset maps (`keyboard_layouts.dart`, `phrases_data.dart`,
`math_speak.dart`, already `Map<AppLanguage, ...>`) keep that shape as-is —
there a missing language entry is one obvious, glaring runtime symptom (the
whole keyboard/phrase set is wrong), not a subtle per-item gap, so the
existing map pattern stays appropriate there. Chosen over the smaller-diff
option of just adding a `uk` case to each ternary, which would leave the
same silent-fallthrough gap for language 4.
