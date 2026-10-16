import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/main.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/services/telemetry_service.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:handy_speak/state/settings_controller.dart';
import 'package:handy_speak/state/speech_feedback_controller.dart';
import 'package:handy_speak/widgets/home_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared headless behaviour-test harness, extracted from the ADDENDUM-03
/// suite during the testing-prep stage. The by-feature suites import it (per
/// `docs/testing-strategy.md` and the `handyspeak-suites` skill) for a single
/// canonical `pumpApp` / [FakeTts] / [readProvider] instead of each suite
/// carrying its own copy.

Map<String, String> _voice(String locale) => {'name': locale, 'locale': locale};
final _defaultVoices = [_voice('en-US'), _voice('cs-CZ')];

/// Live pieces of a pumped app a test may want to inspect/mutate.
class TestApp {
  TestApp(this.storage, this.tts, this.telemetry);

  final StorageService storage;
  final FakeTts tts;

  /// The app's telemetry — disabled (no DSN is ever compiled into tests),
  /// so its sink is the only observable. Canary suites assert against it
  /// (ADDENDUM-06).
  final TelemetryService telemetry;
}

/// Records every `flutter_tts` platform-channel call so tests can assert on
/// exactly what the TTS engine would receive, and answers `getVoices` with a
/// mutable [voices] list so `SpeechService.hasVoiceFor` can be exercised
/// against a controlled "installed voice packs" shape.
class FakeTts {
  final List<MethodCall> calls = [];

  /// Simulated installed voices. Defaults to en/cs only (uk missing), the
  /// realistic "device without a Ukrainian pack" starting point these tests
  /// want. Mutate between actions to simulate a pack being installed.
  List<Map<String, String>> voices = List.of(_defaultVoices);

  /// When set, every `speak` call throws with this message — drives the
  /// tts/speak failure path end-to-end through the real engine adapter
  /// (ADDENDUM-06 canary tests embed a canary here).
  String? speakErrorMessage;

  List<String> get spokenTexts => [
        for (final call in calls)
          if (call.method == 'speak')
            call.arguments is Map
                ? (call.arguments as Map)['text'] as String
                : call.arguments as String,
      ];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isLanguageAvailable':
          return true;
        case 'getVoices':
          return voices;
        case 'speak':
          if (speakErrorMessage != null) throw Exception(speakErrorMessage);
          return 1;
        default:
          return 1;
      }
    });
  }
}

/// Boots the real app root on a landscape-tablet viewport, storage seeded
/// from [prefs]. [screen] sizes the viewport (defaults to 1280×800, comfortably
/// above the settings-dialog breakpoint); [deviceLocale] is what the platform
/// reports at first run (only consulted when no `main_lang` is stored — a fresh
/// install), for the language-seeding behaviours.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size screen = const Size(1280, 800),
  Locale? deviceLocale,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final tts = FakeTts()..install();

  // Mirrors main.dart (ADDENDUM-06): one disabled TelemetryService per app,
  // wired exactly like main() — injected into the instrumented services,
  // fed the composer text, hooks installed before the first frame, app_start
  // breadcrumb after language.load. Exposed on TestApp for assertions.
  final telemetry = TelemetryService();

  final storage = StorageService();
  await storage.init();
  final speech = SpeechService(telemetry: telemetry);
  await speech.init();
  final settings = SettingsController(storage)..load();
  final phrases = PhrasesController(storage, telemetry: telemetry)..load();
  final composer = ComposerController();
  final language = LanguageController(storage, speech, composer)
    ..load(deviceLocale: deviceLocale);

  composer.addListener(() => telemetry.registerSecret(composer.text));
  telemetry.addBreadcrumb('app_start', data: {
    'ui_locale': language.mainLang.locale.toString(),
    'main_lang': language.mainLang.key,
    'second_lang': language.secondLang?.key ?? 'none',
  });

  // Mirrors main.dart: the feedback coordinator listens to the composer and
  // turns input events into feedback-channel speech per the settings toggles.
  final speechFeedback = SpeechFeedbackController(
    composer: composer,
    settings: settings,
    language: language,
    speech: speech,
  );

  telemetry.installErrorHooks();

  await tester.pumpWidget(HandySpeakApp(
    storage: storage,
    speech: speech,
    settings: settings,
    phrases: phrases,
    composer: composer,
    language: language,
    speechFeedback: speechFeedback,
  ));
  await tester.pumpAndSettle();
  return TestApp(storage, tts, telemetry);
}

T readProvider<T>(WidgetTester tester) =>
    Provider.of<T>(tester.element(find.byType(HomePage)), listen: false);
