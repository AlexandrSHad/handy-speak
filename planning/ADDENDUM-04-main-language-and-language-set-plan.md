# HandySpeak — ADDENDUM-04: Main Language & Language Set

## Context

Replaces the always-two-language "language pair" (ADDENDUM-03) with a
parent-configured **language set**: one **main language** plus an optional
**second language**. The UI language is pinned to the main language
(ADR-0002, `docs/adr/0002-ui-locale-pins-to-main-language.md`); the child's
top-bar toggle flips only the *active* language (board + TTS voice) and is
hidden entirely in single-language mode.

**Inputs this plan is derived from:**

- Design: `handoff/HandySpeak_Addendum-04.html` (Claude Design bundle —
  ADDENDUM-04 canvas section + `A04LangSection` source + `a04-*` CSS +
  EN/CS/UK copy table). Scope-confirmation: the design changes exactly two
  surfaces — the Settings → Language section and the top-bar single/dual
  states (artboards 1–8). Everything else in the bundle is pre-existing
  prototype chrome.
- Domain decisions: 18 settled decisions from the design-tree session
  (summarized below), `CONTEXT.md` (glossary: main language, second
  language, language set, active language, UI language), ADR-0002.

**Settled decisions that bind this plan** (do not re-litigate):

| # | Decision |
|---|----------|
| Q1 | "Base" → "Main" rename everywhere, incl. storage keys (pre-prod, no migration) |
| Q2 | "Language pair" → "Language set" (1–2 languages) |
| Q5 | Second language is nullable; key absent in storage = none |
| Q7 | First run: main = device language (code match), else `en` + persistent Settings banner |
| Q8 | Fresh installs start single-language |
| Q12 | Main picker keeps swap semantics; only the Switch removes the second language |
| Q13 | Unsupported-device-language banner is persistent in the Language section |
| Q15 | Single-language mode hides the toggle and reclaims the space (natural reflow) |
| Q16 | Device-language seeding is once-and-persist |
| Q17 | Active language persists across restarts (restore last board, snap to set on load) |
| Q18 | Re-enabling the second language defaults to first supported ≠ main |
| Q6/Q10/Q11/Q14 | No migration path, no wizard, no mailto, no per-surface active-language localization — all deferred (see Deferred) |

**Key codebase facts:**

- `LanguageController` (`lib/state/language_controller.dart`) currently
  owns `_language`/`_baseLang`/`_secondLang` with keys
  `language`/`base_lang`/`second_lang`; `load()` is called once at
  `lib/main.dart:37` (`LanguageController(storage, speech, composer)..load()`).
- `MaterialApp.locale` follows the **active** language today
  (`lib/main.dart:83`) — this plan repins it to main.
- Settings has a reusable `_ToggleRow` (`lib/widgets/settings_sheet.dart:394`,
  name/desc/value/onChanged, dims at 45 % opacity when disabled) and
  `NoticeBanner` — reuse both.
- `_LanguageSection` (`settings_sheet.dart:130`) already does per-slot voice
  checks on open/change/refresh (`_lastBase`/`_lastSecond` diffing) — keep
  that machinery, change only what it renders.
- `AppLanguage` (`lib/core/app_language.dart`) already exposes `short`
  ("EN"/"CZ"/"UK"), `nativeName` (endonym), `key`. Dropdown chips reuse
  `short`; endonyms reuse `nativeName`. **No flags anywhere** (design rule).
- ARB param pattern: `voiceMissingNamed` uses a `{lang}` placeholder
  (`lib/l10n/app_en.arb:49–50`) — the new banner string follows it.
- Test shape: each addendum has `test/<name>_test.dart` +
  `integration_test/<name>_(_test|_suite).dart` sharing one
  `run…Suite()` (see addendum03 pair).

**Copy conflict resolved:** the design's `setMainLangDesc` reads "Menus and
the board are in this language" — but per ADR-0002 the *board* follows the
active language; only menus/chrome are pinned to main. The strings table
below corrects this to "Menus and app texts are always in this language…".

## Implementation steps

### 1. Domain: device-language matching — `lib/core/app_language.dart`

Add a nullable matcher next to `fromKey`:

```dart
/// Matches a device language code (e.g. `PlatformDispatcher`'s
/// `locale.languageCode`) against supported languages; null when the
/// device language isn't supported (falls back to `en`, Q7).
static AppLanguage? fromDeviceCode(String? code) => switch (code) {
      'en' => AppLanguage.en,
      'cs' => AppLanguage.cs,
      'uk' => AppLanguage.uk,
      _ => null,
    };
```

### 2. State: language set — `lib/state/language_controller.dart`

Rework the controller (rename + nullability + seeding). New shape:

```dart
static const _kActiveLang = 'active_lang';   // was 'language'
static const _kMainLang = 'main_lang';       // was 'base_lang'
static const _kSecondLang = 'second_lang';   // unchanged

AppLanguage _mainLang = AppLanguage.en;
AppLanguage? _secondLang;                    // null = single-language (Q5)
AppLanguage _language = AppLanguage.en;      // active

AppLanguage get mainLang => _mainLang;
AppLanguage? get secondLang => _secondLang;

/// The configured languages, main first (glossary: language set).
List<AppLanguage> get set => [_mainLang, if (_secondLang != null) _secondLang!];

/// Whether the device language was unsupported at first-run seeding (Q13
/// banner). Captured once in load(); device-locale changes mid-session
/// don't move it (Q16 rationale).
Locale? deviceLocale;  // kept for the banner's {lang} name
bool deviceLangUnsupported = false;

void load({Locale? deviceLocale}) {
  final storedMain = _storage.getString(_kMainLang);
  if (storedMain == null) {
    // Fresh install (Q16, once-and-persist): seed from device language
    // (Q7), start single-language (Q8).
    this.deviceLocale = deviceLocale;
    _mainLang = AppLanguage.fromDeviceCode(deviceLocale?.languageCode)
        ?? AppLanguage.en;
    deviceLangUnsupported = deviceLocale != null &&
        AppLanguage.fromDeviceCode(deviceLocale.languageCode) == null;
    _secondLang = null;
    _language = _mainLang;
    _persistPair(); _storage.setString(_kActiveLang, _language.key);
  } else {
    _mainLang = _loadSlot(_kMainLang, AppLanguage.en);
    _secondLang = _loadNullableSlot(_kSecondLang); // absent => null
    _language = AppLanguage.fromKey(_storage.getString(_kActiveLang));
    if (!set.contains(_language)) _language = _mainLang; // Q17 snap-back
  }
  _speech.setLanguage(_language.ttsLocale);
}
```

- `setLanguage` unchanged (cancel speech, clear sentence, flip TTS — §6.1.1).
- `setMainLang` = old `setBaseLang` with rename; **keep the swap**
  (`if (next == _secondLang) _secondLang = _mainLang;` — Q12) and the
  orphan snap-back.
- `setSecondLang` = rename; drop the swap branch's nullability hazards
  (`next == _mainLang` can't happen — dropdown excludes main — but keep the
  guard cheap and defensive).
- New:

```dart
/// The only way to remove a second language (Q12). Re-enabling defaults
/// to the first supported language ≠ main (Q18). Disabling while the
/// child left the second language active snaps the active language to
/// main (delegates to setLanguage).
void setSecondEnabled(bool on) {
  if (on) {
    _secondLang ??= AppLanguage.values.firstWhere((l) => l != _mainLang);
  } else {
    _secondLang = null;
    if (_language != _mainLang) { setLanguage(_mainLang); return; }
  }
  _persistPair();
  notifyListeners();
}
```

- `_persistPair` writes `main_lang` + `second_lang` (skip write or write
  empty when null — **remove the key** via `_storage.remove` if the
  storage API supports it, else write and treat `_loadNullableSlot`'s
  absence-or-invalid as null; check `StorageService` and pick the variant
  that keeps "absent = none" unambiguous for Q5/Q18-strictness).
- Update the class doc-comment to the new glossary terms; delete all
  "pair"/"base" wording.

### 3. Locale pin — `lib/main.dart`

- Line 83: `locale: lang.language.locale` → `locale: lang.mainLang.locale`
  (ADR-0002). `supportedLocales` (line 84) unchanged.
- Line 37: pass the device locale into load:
  `..load(deviceLocale: WidgetsBinding.instance.platformDispatcher.locale)`.
  `MaterialApp` now stops rebuilding on every toggle — only main-language
  changes rebuild the tree (note in code comment, cites ADR-0002).

### 4. Strings — `lib/l10n/app_en.arb`, `app_cs.arb`, `app_uk.arb`

Then `puro flutter gen-l10n`. Key changes (design copy table; the one
corrected line flagged):

| ARB key | EN | CS | UK |
|---|---|---|---|
| `settingsLanguageDesc` (value replaced) | The app follows the main language. Add a second language to give the child a toggle in the top bar. | Aplikace se řídí hlavním jazykem. Druhý jazyk přidá dítěti přepínač do horní lišty. | Застосунок іде за основною мовою. Друга мова додає дитині перемикач у верхню панель. |
| `settingsMainLangName` (renamed from `settingsBaseLangName`) | Main language | Hlavní jazyk | Основна мова |
| `settingsMainLangDesc` (renamed, **corrected** from design) | Menus and app texts are always in this language; it comes first in the top bar. | Nabídky a texty aplikace jsou vždy v tomto jazyce; v horní liště je první. | Меню й тексти застосунку завжди цією мовою; у верхній панелі вона перша. |
| `settingsSecondOffHint` (new) | One language only — the top bar shows no language toggle. | Jen jeden jazyk — přepínač jazyků se v horní liště nezobrazuje. | Лише одна мова — перемикача мов у верхній панелі немає. |
| `settingsUnsupportedDeviceLang` (new, `{lang}` placeholder like `voiceMissingNamed`) | This tablet is set to {lang}, which HandySpeak doesn't speak yet. Pick any supported language below. | Tablet je nastavený na jazyk {lang}, který HandySpeak zatím neumí. Níže vyber kterýkoli podporovaný jazyk. | Планшет налаштовано на мову {lang}, якої HandySpeak ще не знає. Обери нижче будь-яку підтримувану мову. |

`settingsSecondLangName`/`settingsSecondLangDesc` keep their keys; design
copy matches existing values. Delete `settingsBaseLangName`/`settingsBaseLangDesc`
after renaming (update the two references in `settings_sheet.dart:319,321`).

### 5. Settings UI — `lib/widgets/settings_sheet.dart`

Rework `_LanguageSection` (line 130) / its State:

- **Main slot**: `_SectionTitle(l10n.settingsMainLangName, subtitle:
  l10n.settingsMainLangDesc)` + dropdown field.
- **Second slot**: a `_ToggleRow` (existing widget, line 394) with
  `name: l10n.settingsSecondLangName, desc: l10n.settingsSecondLangDesc,
  value: secondLang != null, onChanged: (_) => controller.setSecondEnabled(...)`.
  When on: dropdown field below. When off: the hint text
  (`l10n.settingsSecondOffHint`, ink3, 13 px — mirrors `.a04-off-hint`).
- **Dropdown field** (replaces the `picker()` button list, line 233):
  `DropdownButtonFormField<AppLanguage>` styled to the sheet's card idiom —
  `surface2` fill, 16 px radius, 1.5 px `divider` border (focused →
  `primary`), min-height 56 px. Selected + item child: `Row[ _codeChip,
  endonym ]` where chip = `short` in a small bordered pill (surface,
  divider border, 8 px radius, ink2) and endonym = `nativeName`
  (`.a04-select`/`.a04-chip` mapping). Main dropdown lists
  `AppLanguage.values`; second dropdown lists
  `AppLanguage.values.where((l) => l != mainLang)` (Q12: no "None" item).
  Keep test keys — new prefix `settingsLangDropdown_{main|second}` +
  item keys `settingsLangItem_{slot}_{lang}` (the old
  `settingsLangPicker_*` keys die with the button list; update tests).
- **Voice checks**: keep the existing `_lastBase`/`_lastSecond` diff +
  refresh action, renamed (`_lastMain`), and make the second check a
  no-op when `secondLang == null`. `NoticeBanner` under each slot stays.
- **Unsupported banner** (top of the section, below the section note):
  when `controller.deviceLangUnsupported`, an `NoticeBanner`-styled info
  banner (reuse `NoticeBanner`; the design's accent tint is a web-only
  refinement — token reuse wins) with
  `l10n.settingsUnsupportedDeviceLang(<deviceLangName>)`. Name via
  `controller.deviceLocale?.displayName(mainLang.locale)` (intl) — renders
  e.g. "Deutsch" inside an EN UI; fall back to `languageCode.toUpperCase()`
  if the platform returns empty.

### 6. Top bar — `lib/widgets/top_bar.dart`

`_LanguageToggle` (line ~140) reads `controller.pair` → `controller.set`.
In `TopBar.build` (line 13): when `set.length < 2`, omit the
`_LanguageToggle` **and** its trailing `SizedBox(width: AppTokens.s12)`
(Q15 — Row's Spacers reflow naturally; design confirms no extra styling).
Update doc-comment (line 5): "EN/CZ language toggle" → "language-set
toggle, hidden in single-language mode".

### 7. Tests

- Extend `test/language_controller_test.dart`: fresh-install seeding
  (device cs → main cs, second null, active cs; unsupported `de` → main en
  + `deviceLangUnsupported` true; null locale → en), once-and-persist
  (second load ignores changed device locale), Q17 restore + snap-back,
  swap on `setMainLang`, `setSecondEnabled` on/off (re-enable default =
  first ≠ main; disable snaps active to main), persistence key names.
- New `test/addendum04_test.dart` + `integration_test/addendum04_suite.dart`
  + `addendum04_test.dart` sharing `runAddendum04Suite()` (mirror the
  addendum03 pair): settings renders Switch + hint when off, dropdown opens
  and excludes main from the second slot, banner string with device name,
  toggle hidden when single-language, **ADR-0002 pin** (switch active
  language → Settings chrome + Speak label stay in main language), swap
  via main dropdown, voice warnings still per-slot.

## Commit sequence

1. `feat(a04): language set in controller + device-language seeding` —
   steps 1–2 + extended `language_controller_test.dart` (analyze + test).
2. `feat(a04): ARB strings for main language / language set` — step 4
   (gen-l10n committed).
3. `feat(a04): pin UI locale to main language (ADR-0002)` — step 3.
4. `feat(a04): settings language section — dropdowns + second-language switch` — step 5.
5. `feat(a04): hide language toggle in single-language mode` — step 6.
6. `test(a04): addendum04 suites` — step 7 files.
7. `chore: bump version to 0.5.0`.

Run `puro flutter analyze` + `puro flutter test` between each.

## Risks

- **Orphaned active language** on disable-swap-snap paths is the highest
  correctness risk: `setSecondEnabled(false)` and `setMainLang` both
  delegate to `setLanguage` in some branches and notify directly in
  others — keep exactly one notify per user action (existing pattern in
  `setBaseLang` comment). The unit tests must pin each branch.
- **Storage ambiguity for "none"**: if `StorageService` can't remove keys,
  writing an empty string must map back to null in `_loadNullableSlot` —
  otherwise a re-enable resurrects a stale second language (Q18 violation).
- **`displayName` platform variance** (Android vs VM): guard with the
  uppercase-code fallback so the banner never renders an empty name.
- **Dropdown menu styling** is Material-native (overlay), not the design's
  absolutely-positioned card — acceptable per house "map intent, not
  pixels"; the chip+endonym item anatomy is the part that must match.
- Stale generated l10n: regenerate after ARB edits; `analyze` will catch
  dangling `settingsBaseLang*` references.

## Verification

**Unit tests** (`puro flutter test`)
- [ ] Fresh install: device `cs` → main cs, second null, active cs, toggle hidden
- [ ] Fresh install: device `de` → main en, `deviceLangUnsupported` true
- [ ] Fresh install: null device locale → en, no banner flag
- [ ] Once-and-persist: second `load()` with different device locale changes nothing
- [ ] Q17: active language restored; snaps to main when stored active outside set
- [ ] Swap: `setMainLang(second)` swaps, active preserved when in set
- [ ] `setSecondEnabled(true)` after off → first supported ≠ main
- [ ] `setSecondEnabled(false)` while second active → active snaps to main, sentence cleared, speech stopped
- [ ] Storage keys: `main_lang`/`second_lang`/`active_lang` written; absent `second_lang` ⇒ null

**Integration tests** (`puro flutter test integration_test/ -d <device>`)
- [ ] Settings: Switch off shows hint; on shows dropdown; dropdown excludes main
- [ ] Unsupported-device banner shows device language name in main language
- [ ] Toggle hidden in single-language mode; visible with two
- [ ] ADR-0002: switching active language leaves Settings/ Speak label in main language; board + voice flip
- [ ] Per-slot voice warnings survive the rework
- [ ] Persistence across app restart (set + active language)

**Manual checks** (only if device convenient)
- [ ] Real device with Czech system language: first launch opens Czech, single-language
- [ ] Dark theme pass over the new section; contrast via tokens (ink/ink3 on surface2)
- [ ] EN + CS + UK renders of every new string

**AAC checklist**: dropdown field ≥ 56 px tall, menu items ≥ 52 px
(`min-height` in item builder); no flags; endonyms + short-code chips;
Switch is a standard 52×32 Material target (parent-facing surface —
`ForgivingTap` exemption per `docs/forgiving-taps.md`).

## Deferred (explicitly out of scope)

- First-run wizard (own future addendum; "best guess" second language lives there)
- Request-a-language mailto (`url_launcher`, contact address TBD)
- Per-surface active-language localization (Speak label / placeholder / tabs) — parent-configurable extension recorded in ADR-0002
- Storage migration from `base_lang`/`language` keys (pre-prod)

## Critical files

- `lib/core/app_language.dart`
- `lib/state/language_controller.dart`
- `lib/main.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_cs.arb`, `lib/l10n/app_uk.arb`
- `lib/l10n/app_localizations.dart` + `.g`/locale variants (generated)
- `lib/widgets/settings_sheet.dart`
- `lib/widgets/top_bar.dart`
- `test/language_controller_test.dart`
- `test/addendum04_test.dart`
- `integration_test/addendum04_suite.dart`
- `integration_test/addendum04_test.dart`
- `pubspec.yaml` (version bump)
