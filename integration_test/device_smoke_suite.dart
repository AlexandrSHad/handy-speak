import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:handy_speak/main.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/services/tts_engine.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:handy_speak/state/settings_controller.dart';
import 'package:handy_speak/widgets/home_page.dart';

// Single per-release device smoke. Deliberately a pair (this shared body + an
// on-device entry), NOT the usual trio — a headless test/ entry is intentionally
// omitted: adding one would either duplicate the Behavior tier's coverage or
// break the headless green gate (see docs/testing-strategy.md §3 and the
// handyspeak-suites skill). No binding init here — the on-device entry owns it.
void runDeviceSmokeSuite() {
  testWidgets('app boots to HomePage', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Mirror lib/main.dart's service + controller wiring.
    final storage = StorageService();
    await storage.init();

    final speech = SpeechService(engine: FlutterTtsEngine());

    final settings = SettingsController(storage)..load();
    final phrases = PhrasesController(storage)..load();
    final composer = ComposerController();
    final language = LanguageController(storage, speech, composer)..load();

    await tester.pumpWidget(HandySpeakApp(
      storage: storage,
      speech: speech,
      settings: settings,
      phrases: phrases,
      composer: composer,
      language: language,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);

    // TODO(testing-strategy): extend to the full end-to-end walk incl. a genuine
    // speak() call — the on-device path the headless tiers can't prove.
  });
}
