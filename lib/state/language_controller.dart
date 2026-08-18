import 'package:flutter/widgets.dart';

import '../core/app_language.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import 'composer_controller.dart';

/// Owns the active [AppLanguage] and is the single switch that flips the
/// board and voice (IMPLEMENTATION_PLAN Task 2 / §6.1.1). Changing it:
///   1. cancels any in-progress speech,
///   2. clears the composed **sentence** (free text can't be auto-translated;
///      the math problem is glyphs and survives),
///   3. points the TTS engine at the new locale,
///   4. flips the keyboard, symbols and phrase set via notify.
///
/// UI chrome does **not** follow the active language: it stays pinned to the
/// main language (ADR-0002) — only a main-language change moves the app
/// `Locale`. Per-surface active-language localization is a deferred,
/// parent-configurable extension recorded in the ADR.
///
/// Also owns the parent-configured **language set** (ADDENDUM-04): one main
/// language plus an optional second language (`null` = single-language; the
/// child's top-bar toggle shows exactly the languages in [set] and is hidden
/// entirely when there is no second language). [setMainLang] keeps the set
/// symmetric — picking the second language as main swaps the set instead of
/// colliding (only [setSecondEnabled] can drop the second language) — and
/// snaps the active language back onto the set if a change would otherwise
/// orphan it.
class LanguageController extends ChangeNotifier {
  LanguageController(this._storage, this._speech, this._composer);

  final StorageService _storage;
  final SpeechService _speech;
  final ComposerController _composer;

  static const _kActiveLang = 'active_lang';
  static const _kMainLang = 'main_lang';
  static const _kSecondLang = 'second_lang';

  AppLanguage _language = AppLanguage.en;
  AppLanguage get language => _language;

  AppLanguage _mainLang = AppLanguage.en;
  AppLanguage get mainLang => _mainLang;

  AppLanguage? _secondLang;
  AppLanguage? get secondLang => _secondLang;

  /// The configured languages, main first (glossary: language set).
  List<AppLanguage> get set => [
        _mainLang,
        if (_secondLang != null) _secondLang!,
      ];

  /// The device locale seen at first-run seeding, kept for the unsupported-
  /// device-language banner's `{lang}` name (Q13).
  Locale? get deviceLocale => _deviceLocale;
  Locale? _deviceLocale;

  /// Whether the device language was unsupported at first-run seeding (Q13
  /// banner). Captured once in [load]; device-locale changes mid-session
  /// don't move it (Q16 rationale).
  bool get deviceLangUnsupported => _deviceLangUnsupported;
  bool _deviceLangUnsupported = false;

  /// Restores the language set from storage. First run (no `main_lang`
  /// stored): seeds the main language from the device language (Q7, falling
  /// back to `en`) and starts single-language (Q8) — once-and-persist (Q16),
  /// so later loads ignore the device locale entirely. Otherwise restores
  /// the last active language (Q17), snapping it onto the set when the
  /// stored value is missing or outside it.
  void load({Locale? deviceLocale}) {
    final storedMain = _storage.getString(_kMainLang);
    if (storedMain == null) {
      _deviceLocale = deviceLocale;
      _mainLang =
          AppLanguage.fromDeviceCode(deviceLocale?.languageCode) ??
              AppLanguage.en;
      _deviceLangUnsupported = deviceLocale != null &&
          AppLanguage.fromDeviceCode(deviceLocale.languageCode) == null;
      _secondLang = null;
      _language = _mainLang;
      _persistPair();
      _storage.setString(_kActiveLang, _language.key);
    } else {
      _mainLang = _loadSlot(_kMainLang, AppLanguage.en);
      _secondLang = _loadNullableSlot(_kSecondLang);
      _language = AppLanguage.fromKey(_storage.getString(_kActiveLang));
      // The three keys are independent storage writes (see `_persistPair`),
      // so a corrupted or partially-written store could restore an active
      // language outside the set — snap it back rather than leaving it
      // dangling (Q17).
      if (!set.contains(_language)) _language = _mainLang;
    }
    // Align the speech engine with the restored language.
    _speech.setLanguage(_language.ttsLocale);
  }

  AppLanguage _loadSlot(String key, AppLanguage fallback) {
    final raw = _storage.getString(key);
    return raw == null ? fallback : AppLanguage.fromKey(raw);
  }

  /// Absent key = no second language (Q5). An unrecognized value is treated
  /// the same way — "none" is never encoded, only absent.
  AppLanguage? _loadNullableSlot(String key) {
    final raw = _storage.getString(key);
    if (raw == null) return null;
    for (final l in AppLanguage.values) {
      if (l.key == raw) return l;
    }
    return null;
  }

  void setLanguage(AppLanguage next) {
    if (next == _language) return;
    _language = next;
    _storage.setString(_kActiveLang, next.key);

    // §6.1.1 — cancel speech, clear the sentence (math survives), flip voice.
    _speech.stop();
    _composer.clearSentence();
    _speech.setLanguage(next.ttsLocale);

    notifyListeners();
  }

  /// Sets the main language. If [next] is already the second language, the
  /// set swaps instead of colliding (Q12 — only [setSecondEnabled] removes
  /// the second language). If the active language is orphaned outside the
  /// resulting set, it snaps to the new main (delegating to [setLanguage],
  /// which notifies on its own — no double notify here).
  void setMainLang(AppLanguage next) {
    if (next == _mainLang) return;
    if (next == _secondLang) _secondLang = _mainLang;
    _mainLang = next;
    _persistPair();
    if (!set.contains(_language)) {
      setLanguage(_mainLang);
      return;
    }
    notifyListeners();
  }

  /// Sets the second language. Guarded no-op when `next == _mainLang` — the
  /// dropdown excludes main, so it can't happen via the UI; the guard stays
  /// cheap and defensive.
  void setSecondLang(AppLanguage next) {
    if (next == _secondLang || next == _mainLang) return;
    _secondLang = next;
    _persistPair();
    if (!set.contains(_language)) {
      setLanguage(_mainLang);
      return;
    }
    notifyListeners();
  }

  /// The only way to remove a second language (Q12). Re-enabling defaults
  /// to the first supported language ≠ main (Q18). Disabling while the
  /// child left the second language active snaps the active language to
  /// main (delegates to setLanguage, which notifies on its own).
  ///
  /// `_persistPair` runs on **both** branches *before* any `setLanguage`
  /// delegation — persist-then-notify, so a disable can never leave a stale
  /// `second_lang` key behind (Q18).
  void setSecondEnabled(bool on) {
    if (on) {
      _secondLang ??= AppLanguage.values.firstWhere((l) => l != _mainLang);
    } else {
      _secondLang = null;
    }
    _persistPair(); // removes the second_lang key when null
    if (!on && _language != _mainLang) {
      setLanguage(_mainLang); // notifies — exactly one notify on this path
      return;
    }
    notifyListeners();
  }

  void _persistPair() {
    _storage.setString(_kMainLang, _mainLang.key);
    if (_secondLang == null) {
      // Absent key = no second language (Q5) — remove, never encode "none".
      _storage.remove(_kSecondLang);
    } else {
      _storage.setString(_kSecondLang, _secondLang!.key);
    }
  }
}
