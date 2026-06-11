// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'HandySpeak';

  @override
  String get modeKeyboard => 'Klávesnice';

  @override
  String get modeSymbols => 'Symboly';

  @override
  String get settings => 'Nastavení';

  @override
  String get speak => 'Mluvit';

  @override
  String get speaking => 'Mluvím…';

  @override
  String get clear => 'Smazat';

  @override
  String get myPhrases => 'Moje fráze';

  @override
  String get composePlaceholder => 'Ťukej na klávesy nebo symboly…';

  @override
  String get keySpace => 'mezera';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slov',
      few: '$count slova',
      one: '1 slovo',
      zero: '0 slov',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Jazyk';

  @override
  String get settingsLanguageDesc =>
      'Přepne celou tabulku i mluvící hlas. Děti mohou ťuknout i na EN / CZ nahoře.';

  @override
  String get settingsVoice => 'Mluvený hlas';

  @override
  String get settingsMoodName => 'Nálady hlasu';

  @override
  String get settingsMoodDesc =>
      'Dítě si může vybrat náladu, která mění výšku a rychlost hlasu. Vypnuto = jeden stálý hlas.';

  @override
  String get settingsPhrases => 'Rodič · Fráze';

  @override
  String get settingsUsed => 'použito';

  @override
  String get settingsPin => 'Připnout';

  @override
  String get settingsUnpin => 'Odepnout';

  @override
  String get settingsAddPhrase => 'Přidej frázi, kterou dítě rychle řekne…';

  @override
  String get settingsAdd => 'Přidat';

  @override
  String get settingsAccessibility => 'Přístupnost';

  @override
  String get settingsHapticName => 'Vibrace';

  @override
  String get settingsHapticDesc =>
      'Zavibruje při stisku klávesy/dlaždice (kde to jde).';

  @override
  String get settingsDarkName => 'Tmavý režim';

  @override
  String get settingsDarkDesc => 'Méně kontrastní plochy pro použití v šeru.';

  @override
  String get settingsBigLettersName => 'Velká písmena';

  @override
  String get settingsBigLettersDesc =>
      'Všechna písmena se zobrazí jako velká a klávesa shift se uzamkne. Pomáhá dětem, které ještě nečtou malá písmena — řeč se nemění.';

  @override
  String get settingsShowPhrasesName => 'Zobrazit lištu frází';

  @override
  String get settingsShowPhrasesDesc =>
      'Lišta rychlých frází nad klávesnicí. Vypni pro děti, které ještě nečtou — klávesy a symboly se zvětší.';

  @override
  String get settingsPhrasesHiddenNote =>
      'Na tabulce skryto — fráze tu zůstávají uložené a vrátí se po zapnutí.';

  @override
  String get voiceMissing =>
      'V tabletu zatím není český hlas — přidej ho v nastavení řeči zařízení pro nejlepší výslovnost.';
}
