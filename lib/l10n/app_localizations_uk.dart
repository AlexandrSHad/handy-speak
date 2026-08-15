// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'HandySpeak';

  @override
  String get modeKeyboard => 'Клавіатура';

  @override
  String get modeSymbols => 'Символи';

  @override
  String get modeMath => 'Лічба';

  @override
  String get settings => 'Налаштування';

  @override
  String get speak => 'Говорити';

  @override
  String get speaking => 'Говорю…';

  @override
  String get clear => 'Стерти';

  @override
  String get myPhrases => 'Мої фрази';

  @override
  String get composePlaceholder => 'Торкай клавіші або символи…';

  @override
  String get keySpace => 'пробіл';

  @override
  String get keyBackspace => 'Стерти';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count слів',
      many: '$count слів',
      few: '$count слова',
      one: '$count слово',
      zero: '0 слів',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Мова';

  @override
  String get settingsLanguageDesc =>
      'Обери дві мови для верхньої панелі. Дотик перемикає всю дошку й голос.';

  @override
  String get settingsBaseLangName => 'Основна мова';

  @override
  String get settingsBaseLangDesc =>
      'Перша у верхній панелі; дошка починає з неї.';

  @override
  String get settingsSecondLangName => 'Друга мова';

  @override
  String get settingsSecondLangDesc =>
      'Інша мова, на яку дитина може перемкнутися.';

  @override
  String get settingsVoice => 'Голос мовлення';

  @override
  String get settingsMoodName => 'Голоси настрою';

  @override
  String get settingsMoodDesc =>
      'Дитина може обрати настрій, що змінює висоту й швидкість голосу. Вимкнено = один рівний голос.';

  @override
  String get settingsPhrases => 'Батьки · Фрази';

  @override
  String get settingsUsed => 'вжито';

  @override
  String get settingsPin => 'Закріпити';

  @override
  String get settingsUnpin => 'Відкріпити';

  @override
  String get settingsAddPhrase => 'Додай фразу, яку дитина швидко скаже…';

  @override
  String get settingsAdd => 'Додати';

  @override
  String get settingsAccessibility => 'Доступність';

  @override
  String get settingsHapticName => 'Вібрація';

  @override
  String get settingsHapticDesc =>
      'Вібрує при натисканні клавіші/плитки (де підтримується).';

  @override
  String get settingsDarkName => 'Темний режим';

  @override
  String get settingsDarkDesc =>
      'Менш контрастні поверхні для темного приміщення.';

  @override
  String get settingsBigLettersName => 'Великі літери';

  @override
  String get settingsBigLettersDesc =>
      'Усі літери показуються великими, клавіша shift блокується. Допомагає дітям, які ще не читають малі літери — мовлення не змінюється.';

  @override
  String get settingsShowPhrasesName => 'Показувати панель фраз';

  @override
  String get settingsShowPhrasesDesc =>
      'Смужка швидких фраз над клавіатурою. Вимкни для дітей, які ще не читають — клавіші й символи стануть більшими.';

  @override
  String get settingsPhrasesHiddenNote =>
      'На дошці приховано — фрази зберігаються тут і повернуться після увімкнення.';

  @override
  String get preparingVoice => 'Готую голос…';

  @override
  String get voiceUnavailable => 'Голос недоступний';

  @override
  String get voiceUnavailableDetail =>
      'Планшет поки не має доступу до голосу мовлення, тому застосунок ще не може говорити. Відкрий налаштування мовлення (синтез мовлення) пристрою і встанови голос.';

  @override
  String voiceMissingNamed(String lang) {
    return 'На планшеті ще немає голосу для мови «$lang» — додай його в налаштуваннях мовлення пристрою для найкращої вимови.';
  }

  @override
  String get closeLabel => 'Закрити';

  @override
  String get settingsRefreshVoices => 'Оновити перевірку голосу';
}
