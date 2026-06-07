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

  final speech = SpeechService();
  await speech.init();

  final settings = SettingsController(storage)..load();
  final phrases = PhrasesController(storage)..load();
  final composer = ComposerController();
  final language = LanguageController(storage, speech, composer)..load();

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
            locale: lang.language.locale,
            supportedLocales: const [Locale('en'), Locale('cs')],
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
