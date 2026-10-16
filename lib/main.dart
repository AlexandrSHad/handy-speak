import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'services/speech_service.dart';
import 'services/storage_service.dart';
import 'services/telemetry_service.dart';
import 'services/tts_engine.dart';
import 'state/composer_controller.dart';
import 'state/language_controller.dart';
import 'state/phrases_controller.dart';
import 'state/settings_controller.dart';
import 'state/speech_feedback_controller.dart';
import 'widgets/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ADDENDUM-06 / ADR-0004: error telemetry. Without a compiled-in DSN
  // (see dart_defines.example.json) nothing is initialised and nothing can
  // send — `run()` below is the entire app, telemetry-dark except for the
  // in-memory sink. Telemetry is deliberately NOT a provider: no widget
  // consumes it (the Settings toggle is deferred by ADR-0004).
  final telemetry = TelemetryService();

  Future<void> run() async {
    // Landscape tablet target (IMPLEMENTATION_PLAN §1).
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final storage = StorageService();
    try {
      await storage.init();
    } catch (e, st) {
      // The app cannot run without storage; the capture adds context before
      // the crash surfaces. Tags stay empty — nothing else is allowlisted.
      unawaited(telemetry.captureError(e, st, scope: 'storage/init'));
      rethrow;
    }

    // TTS binds in the background (constructor); we deliberately do NOT await it
    // so the first frame paints immediately instead of sitting on a white screen
    // while the Android TTS service binds. The Speak button shows a spinner until
    // SpeechService.status flips to ready (or an error if it never binds).
    final speech =
        SpeechService(engine: FlutterTtsEngine(), telemetry: telemetry);

    final settings = SettingsController(storage)..load();
    final phrases =
        PhrasesController(storage, telemetry: telemetry)..load();
    final composer = ComposerController();
    final language = LanguageController(storage, speech, composer)
      ..load(deviceLocale: WidgetsBinding.instance.platformDispatcher.locale);

    // The redaction ledger tracks the composer text via its notifications —
    // the controller stays unaware telemetry exists (ADDENDUM-06).
    composer.addListener(() => telemetry.registerSecret(composer.text));

    // Startup breadcrumb: metadata only, values known once language.load
    // has settled (ADR-0002: the UI locale IS the main language).
    telemetry.addBreadcrumb('app_start', data: {
      'ui_locale': language.mainLang.locale.toString(),
      'main_lang': language.mainLang.key,
      'second_lang': language.secondLang?.key ?? 'none',
    });

    // Typing speech feedback (letter echo / finished words / symbol & phrase
    // taps): a listener outside the widget tree — nothing renders from it, but
    // the Provider below keeps it alive alongside the controllers it reads.
    final speechFeedback = SpeechFeedbackController(
      composer: composer,
      settings: settings,
      language: language,
      speech: speech,
    );

    // Framework/platform errors can embed Text widget contents — the child's
    // message — so they route through the same redaction. The hooks chain to
    // whatever owned the handlers before them (ADDENDUM-06).
    telemetry.installErrorHooks();

    runApp(HandySpeakApp(
      storage: storage,
      speech: speech,
      settings: settings,
      phrases: phrases,
      composer: composer,
      language: language,
      speechFeedback: speechFeedback,
    ));
  }

  if (telemetry.enabled) {
    await SentryFlutter.init(telemetry.configure, appRunner: run);
  } else {
    telemetry.warnIfDisabled();
    await run();
  }
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
    required this.speechFeedback,
  });

  final StorageService storage;
  final SpeechService speech;
  final SettingsController settings;
  final PhrasesController phrases;
  final ComposerController composer;
  final LanguageController language;
  final SpeechFeedbackController speechFeedback;

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
        Provider<SpeechFeedbackController>.value(value: speechFeedback),
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
