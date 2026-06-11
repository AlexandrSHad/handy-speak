// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HandySpeak';

  @override
  String get modeKeyboard => 'Keyboard';

  @override
  String get modeSymbols => 'Symbols';

  @override
  String get settings => 'Settings';

  @override
  String get speak => 'Speak';

  @override
  String get speaking => 'Speaking…';

  @override
  String get clear => 'Clear';

  @override
  String get myPhrases => 'My Phrases';

  @override
  String get composePlaceholder => 'Tap keys or symbols to compose…';

  @override
  String get keySpace => 'space';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
      zero: '0 words',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageDesc =>
      'Switch the whole board and the speaking voice. Kids can also tap EN / CZ in the top bar.';

  @override
  String get settingsVoice => 'Speaking voice';

  @override
  String get settingsMoodName => 'Mood voices';

  @override
  String get settingsMoodDesc =>
      'Let the child pick a mood that changes the voice\'s pitch and speed. Off uses one steady voice.';

  @override
  String get settingsPhrases => 'Parent · Phrases';

  @override
  String get settingsUsed => 'used';

  @override
  String get settingsPin => 'Pin';

  @override
  String get settingsUnpin => 'Unpin';

  @override
  String get settingsAddPhrase => 'Add a phrase the child can quickly speak…';

  @override
  String get settingsAdd => 'Add';

  @override
  String get settingsAccessibility => 'Accessibility';

  @override
  String get settingsHapticName => 'Haptic feedback';

  @override
  String get settingsHapticDesc =>
      'Vibrate on key/card press (where supported).';

  @override
  String get settingsDarkName => 'Dark mode';

  @override
  String get settingsDarkDesc => 'Lower-contrast surfaces for low-light use.';

  @override
  String get settingsBigLettersName => 'Big letters';

  @override
  String get settingsBigLettersDesc =>
      'Show every letter as a capital and lock the shift key. Helps kids who don\'t read lowercase yet — speech is unchanged.';

  @override
  String get settingsShowPhrasesName => 'Show phrase shortcuts';

  @override
  String get settingsShowPhrasesDesc =>
      'The quick-phrase strip above the keyboard. Turn off for kids who don\'t read yet — keys and symbols grow bigger.';

  @override
  String get settingsPhrasesHiddenNote =>
      'Hidden on the board — phrases stay saved here and come back when you switch this on.';

  @override
  String get voiceMissing =>
      'No Czech voice on this tablet yet — add one in your device\'s speech settings for the best pronunciation.';
}
