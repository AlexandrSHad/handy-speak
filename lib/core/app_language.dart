import 'package:flutter/widgets.dart';

/// The two languages the POC supports. The active language flips *everything*
/// at once: UI chrome, keyboard layout, symbol word set, My Phrases set, and
/// the TTS voice. See IMPLEMENTATION_PLAN §2 / §6.
enum AppLanguage {
  en,
  cs;

  /// Flutter [Locale] used to resolve generated UI strings.
  Locale get locale => Locale(name);

  /// BCP-47 locale handed to the speech engine.
  String get ttsLocale => this == AppLanguage.cs ? 'cs-CZ' : 'en-US';

  /// Short label shown in the top-bar language toggle ("EN" / "CZ").
  String get short => this == AppLanguage.cs ? 'CZ' : 'EN';

  /// Endonym shown in the settings language list.
  String get nativeName => this == AppLanguage.cs ? 'Čeština' : 'English';

  /// `shared_preferences` key suffix, e.g. `phrases_en` / `phrases_cs`.
  String get key => name;

  static AppLanguage fromKey(String? key) =>
      key == 'cs' ? AppLanguage.cs : AppLanguage.en;
}
