import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'HandySpeak'**
  String get appTitle;

  /// No description provided for @modeKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get modeKeyboard;

  /// No description provided for @modeSymbols.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get modeSymbols;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @speak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get speak;

  /// No description provided for @speaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking…'**
  String get speaking;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @myPhrases.
  ///
  /// In en, this message translates to:
  /// **'My Phrases'**
  String get myPhrases;

  /// No description provided for @composePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tap keys or symbols to compose…'**
  String get composePlaceholder;

  /// No description provided for @keySpace.
  ///
  /// In en, this message translates to:
  /// **'space'**
  String get keySpace;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 words} =1{1 word} other{{count} words}}'**
  String wordCount(int count);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch the whole board and the speaking voice. Kids can also tap EN / CZ in the top bar.'**
  String get settingsLanguageDesc;

  /// No description provided for @settingsVoice.
  ///
  /// In en, this message translates to:
  /// **'Speaking voice'**
  String get settingsVoice;

  /// No description provided for @settingsMoodName.
  ///
  /// In en, this message translates to:
  /// **'Mood voices'**
  String get settingsMoodName;

  /// No description provided for @settingsMoodDesc.
  ///
  /// In en, this message translates to:
  /// **'Let the child pick a mood that changes the voice\'s pitch and speed. Off uses one steady voice.'**
  String get settingsMoodDesc;

  /// No description provided for @settingsPhrases.
  ///
  /// In en, this message translates to:
  /// **'Parent · Phrases'**
  String get settingsPhrases;

  /// No description provided for @settingsUsed.
  ///
  /// In en, this message translates to:
  /// **'used'**
  String get settingsUsed;

  /// No description provided for @settingsPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get settingsPin;

  /// No description provided for @settingsUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get settingsUnpin;

  /// No description provided for @settingsAddPhrase.
  ///
  /// In en, this message translates to:
  /// **'Add a phrase the child can quickly speak…'**
  String get settingsAddPhrase;

  /// No description provided for @settingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get settingsAdd;

  /// No description provided for @settingsAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get settingsAccessibility;

  /// No description provided for @settingsHapticName.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHapticName;

  /// No description provided for @settingsHapticDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on key/card press (where supported).'**
  String get settingsHapticDesc;

  /// No description provided for @settingsDarkName.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkName;

  /// No description provided for @settingsDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Lower-contrast surfaces for low-light use.'**
  String get settingsDarkDesc;

  /// No description provided for @settingsBigLettersName.
  ///
  /// In en, this message translates to:
  /// **'Big letters'**
  String get settingsBigLettersName;

  /// No description provided for @settingsBigLettersDesc.
  ///
  /// In en, this message translates to:
  /// **'Show every letter as a capital and lock the shift key. Helps kids who don\'t read lowercase yet — speech is unchanged.'**
  String get settingsBigLettersDesc;

  /// No description provided for @settingsShowPhrasesName.
  ///
  /// In en, this message translates to:
  /// **'Show phrase shortcuts'**
  String get settingsShowPhrasesName;

  /// No description provided for @settingsShowPhrasesDesc.
  ///
  /// In en, this message translates to:
  /// **'The quick-phrase strip above the keyboard. Turn off for kids who don\'t read yet — keys and symbols grow bigger.'**
  String get settingsShowPhrasesDesc;

  /// No description provided for @settingsPhrasesHiddenNote.
  ///
  /// In en, this message translates to:
  /// **'Hidden on the board — phrases stay saved here and come back when you switch this on.'**
  String get settingsPhrasesHiddenNote;

  /// No description provided for @voiceMissing.
  ///
  /// In en, this message translates to:
  /// **'No Czech voice on this tablet yet — add one in your device\'s speech settings for the best pronunciation.'**
  String get voiceMissing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
