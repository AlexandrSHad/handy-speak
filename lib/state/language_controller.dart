import 'package:flutter/foundation.dart';

import '../core/app_language.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import 'composer_controller.dart';

/// Owns the active [AppLanguage] and is the single switch that flips
/// everything (IMPLEMENTATION_PLAN Task 2 / §6.1.1). Changing it:
///   1. cancels any in-progress speech,
///   2. clears the composed **sentence** (free text can't be auto-translated;
///      the math problem is glyphs and survives),
///   3. points the TTS engine at the new locale,
///   4. flips the app `Locale`, keyboard, symbols and phrase set via notify.
///
/// Also owns the parent-chosen **language pair** (ADDENDUM-03): the child's
/// top-bar toggle always shows exactly [baseLang] and [secondLang], never
/// all of [AppLanguage.values]. [setBaseLang]/[setSecondLang] keep the pair
/// symmetric — picking the other slot's language swaps the pair instead of
/// colliding — and snap the active language back onto the pair if the
/// change would otherwise orphan it outside the new pair.
class LanguageController extends ChangeNotifier {
  LanguageController(this._storage, this._speech, this._composer);

  final StorageService _storage;
  final SpeechService _speech;
  final ComposerController _composer;

  static const _kLang = 'language';
  static const _kBaseLang = 'base_lang';
  static const _kSecondLang = 'second_lang';

  AppLanguage _language = AppLanguage.en;
  AppLanguage get language => _language;

  AppLanguage _baseLang = AppLanguage.en;
  AppLanguage get baseLang => _baseLang;

  AppLanguage _secondLang = AppLanguage.cs;
  AppLanguage get secondLang => _secondLang;

  /// The two languages shown in the child's top-bar toggle, base first.
  List<AppLanguage> get pair => [_baseLang, _secondLang];

  void load() {
    _baseLang = _loadPairSlot(_kBaseLang, AppLanguage.en);
    _secondLang = _loadPairSlot(_kSecondLang, AppLanguage.cs);
    _language = AppLanguage.fromKey(_storage.getString(_kLang));
    // `_kLang`/`_kBaseLang`/`_kSecondLang` are three independent storage
    // writes (see `_persistPair`) — unlike setBaseLang/setSecondLang, a
    // load() has no in-memory invariant to lean on, so a corrupted or
    // partially-written store could restore a language outside the pair.
    // Snap it back onto the pair rather than leaving it dangling.
    if (!pair.contains(_language)) _language = _baseLang;
    // Align the speech engine with the restored language.
    _speech.setLanguage(_language.ttsLocale);
  }

  AppLanguage _loadPairSlot(String key, AppLanguage fallback) {
    final raw = _storage.getString(key);
    return raw == null ? fallback : AppLanguage.fromKey(raw);
  }

  void setLanguage(AppLanguage next) {
    if (next == _language) return;
    _language = next;
    _storage.setString(_kLang, next.key);

    // §6.1.1 — cancel speech, clear the sentence (math survives), flip voice.
    _speech.stop();
    _composer.clearSentence();
    _speech.setLanguage(next.ttsLocale);

    notifyListeners();
  }

  /// Sets the base (first/left) language. If [next] is already the second
  /// language, the pair swaps instead of colliding. If the active language
  /// is orphaned outside the resulting pair, it snaps to the new base
  /// (delegating to [setLanguage], which notifies on its own — no double
  /// notify here).
  void setBaseLang(AppLanguage next) {
    if (next == _baseLang) return;
    if (next == _secondLang) _secondLang = _baseLang;
    _baseLang = next;
    _persistPair();
    if (!pair.contains(_language)) {
      setLanguage(_baseLang);
      return;
    }
    notifyListeners();
  }

  /// Sets the second language. Mirrors [setBaseLang].
  void setSecondLang(AppLanguage next) {
    if (next == _secondLang) return;
    if (next == _baseLang) _baseLang = _secondLang;
    _secondLang = next;
    _persistPair();
    if (!pair.contains(_language)) {
      setLanguage(_baseLang);
      return;
    }
    notifyListeners();
  }

  void _persistPair() {
    _storage.setString(_kBaseLang, _baseLang.key);
    _storage.setString(_kSecondLang, _secondLang.key);
  }
}
