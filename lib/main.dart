import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'services/speech_service.dart';
import 'services/storage_service.dart';
import 'state/composer_controller.dart';
import 'state/language_controller.dart';
import 'state/phrases_controller.dart';
import 'state/settings_controller.dart';
import 'widgets/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Landscape tablet target (IMPLEMENTATION_PLAN §1).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final storage = StorageService();
  await storage.init();

  // TTS binds in the background (constructor); we deliberately do NOT await it
  // so the first frame paints immediately instead of sitting on a white screen
  // while the Android TTS service binds. The Speak button shows a spinner until
  // SpeechService.status flips to ready (or an error if it never binds).
  final speech = SpeechService();

  final settings = SettingsController(storage)..load();
  final phrases = PhrasesController(storage)..load();
  final composer = ComposerController();
  final language = LanguageController(storage, speech, composer)
    ..load(deviceLocale: WidgetsBinding.instance.platformDispatcher.locale);

  runApp(HandySpeakApp(
    storage: storage,
    speech: speech,
    settings: settings,
    phrases: phrases,
    composer: composer,
    language: language,
  ));
}

class HandySpeakApp extends StatelessWidget {
  const HandySpeakApp({
    super.key,
    required this.storage,
    required this.speech,
    required this.settings,
    required this.phrases,
    required this.composer,
    required this.language,
  });

  final StorageService storage;
  final SpeechService speech;
  final SettingsController settings;
  final PhrasesController phrases;
  final ComposerController composer;
  final LanguageController language;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: speech),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: phrases),
        ChangeNotifierProvider.value(value: composer),
        ChangeNotifierProvider.value(value: language),
      ],
      child: Consumer2<LanguageController, SettingsController>(
        builder: (context, lang, settings, _) {
          return MaterialApp(
            title: 'HandySpeak',
            debugShowCheckedModeBanner: false,
            // ADR-0002: the UI locale is pinned to the MAIN language — the
            // locale stops moving on every active-language toggle (the
            // Consumer below still rebuilds so the board flips; only a
            // main-language change moves the locale itself).
            locale: lang.mainLang.locale,
            supportedLocales: const [Locale('en'), Locale('cs'), Locale('uk')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.dark ? ThemeMode.dark : ThemeMode.light,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
