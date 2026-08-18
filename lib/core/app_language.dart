import 'package:flutter/widgets.dart';

/// The languages the app supports. The child's top-bar toggle shows exactly
/// two of these at once (the parent-chosen language pair — see
/// `LanguageController`); switching the active language flips *everything*:
/// UI chrome, keyboard layout, symbol word set, My Phrases set, and the TTS
/// voice. See IMPLEMENTATION_PLAN §2 / §6, ADDENDUM-03.
enum AppLanguage {
  en,
  cs,
  uk;

  /// Flutter [Locale] used to resolve generated UI strings.
  Locale get locale => Locale(name);

  /// BCP-47 locale handed to the speech engine.
  String get ttsLocale => switch (this) {
        AppLanguage.en => 'en-US',
        AppLanguage.cs => 'cs-CZ',
        AppLanguage.uk => 'uk-UA',
      };

  /// Short label shown in the top-bar language toggle ("EN" / "CZ" / "UK").
  String get short => switch (this) {
        AppLanguage.en => 'EN',
        AppLanguage.cs => 'CZ',
        AppLanguage.uk => 'UK',
      };

  /// Endonym shown in the settings language list.
  String get nativeName => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.cs => 'Čeština',
        AppLanguage.uk => 'Українська',
      };

  /// `shared_preferences` key suffix, e.g. `phrases_en` / `phrases_cs` /
  /// `phrases_uk`. Also reused as the voice-locale-prefix match in
  /// `SpeechService.hasVoiceFor`.
  String get key => name;

  static AppLanguage fromKey(String? key) => switch (key) {
        'cs' => AppLanguage.cs,
        'uk' => AppLanguage.uk,
        _ => AppLanguage.en,
      };

  /// Matches a device language code (e.g. `PlatformDispatcher`'s
  /// `locale.languageCode`) against supported languages; null when the
  /// device language isn't supported (falls back to `en`, ADDENDUM-04 Q7).
  static AppLanguage? fromDeviceCode(String? code) => switch (code) {
        'en' => AppLanguage.en,
        'cs' => AppLanguage.cs,
        'uk' => AppLanguage.uk,
        _ => null,
      };
}
