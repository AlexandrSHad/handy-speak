import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ADDENDUM-03 LanguageController tests: the parent-chosen base/second
// language pair — swap-on-conflict, snap-to-base when a pair change orphans
// the active language, and persistence round-trip. Same platform-channel
// faking pattern as `composer_controller_math_test.dart`'s LanguageController
// group (duplicated here to keep suites independent).

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('LanguageController · pair defaults', () {
    test('defaults to base=en, second=cs when nothing is persisted',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      expect(lang.baseLang, AppLanguage.en);
      expect(lang.secondLang, AppLanguage.cs);
      expect(lang.pair, [AppLanguage.en, AppLanguage.cs]);
    });
  });

  group('LanguageController · swap-on-conflict', () {
    test('setBaseLang to the current second language swaps the pair',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      // base=en, second=cs. Picking cs as base must swap, never collide.
      lang.setBaseLang(AppLanguage.cs);

      expect(lang.baseLang, AppLanguage.cs);
      expect(lang.secondLang, AppLanguage.en);
      expect(lang.pair, [AppLanguage.cs, AppLanguage.en]);
    });

    test('setSecondLang to the current base language swaps the pair',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      // base=en, second=cs. Picking en as second must swap, never collide.
      lang.setSecondLang(AppLanguage.en);

      expect(lang.baseLang, AppLanguage.cs);
      expect(lang.secondLang, AppLanguage.en);
      expect(lang.pair, [AppLanguage.cs, AppLanguage.en]);
    });

    test('non-conflicting change to either slot never swaps', () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      lang.setSecondLang(AppLanguage.uk);
      expect(lang.baseLang, AppLanguage.en);
      expect(lang.secondLang, AppLanguage.uk);

      lang.setBaseLang(AppLanguage.cs);
      expect(lang.baseLang, AppLanguage.cs);
      expect(lang.secondLang, AppLanguage.uk);
    });
  });

  group('LanguageController · snap-to-base on orphaning', () {
    test('changing a slot away from the active language snaps it to base',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      // Active language is the second slot (cs).
      lang.setLanguage(AppLanguage.cs);
      expect(lang.language, AppLanguage.cs);

      // Replacing the second slot with uk orphans cs from the pair — the
      // active language must snap back to base (en), not stay dangling.
      lang.setSecondLang(AppLanguage.uk);

      expect(lang.pair, [AppLanguage.en, AppLanguage.uk]);
      expect(lang.language, AppLanguage.en);
    });

    test('orphaning snap notifies exactly once (no double notify)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      lang.setLanguage(AppLanguage.cs);

      var notifyCount = 0;
      lang.addListener(() => notifyCount++);

      lang.setSecondLang(AppLanguage.uk); // orphans cs -> snaps to base

      expect(notifyCount, 1,
          reason:
              'setSecondLang delegates the orphan-snap to setLanguage(), '
              'which already notifies — it must not also call '
              'notifyListeners() itself on that path');
    });

    test('a non-orphaning pair change still notifies once', () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      var notifyCount = 0;
      lang.addListener(() => notifyCount++);

      // Active language stays en (base) throughout — no orphan.
      lang.setSecondLang(AppLanguage.uk);

      expect(notifyCount, 1);
    });
  });

  group('LanguageController · persistence round-trip', () {
    test('base/second lang survive a reload from the same storage',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage1 = StorageService();
      await storage1.init();
      final speech1 = SpeechService();
      await speech1.init();
      final composer1 = ComposerController();
      final lang1 = LanguageController(storage1, speech1, composer1)..load();

      lang1.setBaseLang(AppLanguage.uk);
      lang1.setSecondLang(AppLanguage.en);
      expect(lang1.pair, [AppLanguage.uk, AppLanguage.en]);

      // Fresh controller instance, same (mocked) shared_preferences store.
      final storage2 = StorageService();
      await storage2.init();
      final speech2 = SpeechService();
      await speech2.init();
      final composer2 = ComposerController();
      final lang2 = LanguageController(storage2, speech2, composer2)..load();

      expect(lang2.baseLang, AppLanguage.uk);
      expect(lang2.secondLang, AppLanguage.en);
      expect(lang2.pair, [AppLanguage.uk, AppLanguage.en]);
    });
  });
}

/// Minimal `flutter_tts` platform-channel fake: records calls and answers
/// every method as success (1) so SpeechService binds to `ready`.
class _FakeTts {
  final List<MethodCall> calls = [];
  static const _channel = MethodChannel('flutter_tts');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isLanguageAvailable':
          return true;
        default:
          return 1;
      }
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
