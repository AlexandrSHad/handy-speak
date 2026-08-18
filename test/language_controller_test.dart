import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ADDENDUM-04 LanguageController tests: the parent-configured language set
// (main + optional second), device-language seeding on first run, Q17 active
// restore with snap-back, swap-on-conflict, setSecondEnabled on/off, notify
// counts, and persistence round-trips. Same platform-channel faking pattern
// as `composer_controller_math_test.dart`'s LanguageController group
// (duplicated here to keep suites independent).

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // Builds a loaded controller over fresh mock storage. [prefs] seeds the
  // store *before* load (key presence decides fresh-install vs. restore);
  // [deviceLocale] is what the platform would report at first run.
  Future<(LanguageController, StorageService, ComposerController, _FakeTts)>
      boot({
    Map<String, Object> prefs = const {},
    Locale? deviceLocale,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final tts = _FakeTts()..install();
    addTearDown(tts.uninstall);

    final storage = StorageService();
    await storage.init();
    final speech = SpeechService();
    await speech.init();
    final composer = ComposerController();
    final lang = LanguageController(storage, speech, composer)
      ..load(deviceLocale: deviceLocale);
    return (lang, storage, composer, tts);
  }

  group('LanguageController · fresh-install seeding', () {
    test('device cs -> main cs, no second language, active cs', () async {
      final (lang, storage, _, _) =
          await boot(deviceLocale: const Locale('cs'));

      expect(lang.mainLang, AppLanguage.cs);
      expect(lang.secondLang, isNull);
      expect(lang.language, AppLanguage.cs);
      expect(lang.set, [AppLanguage.cs]);
      expect(lang.deviceLangUnsupported, isFalse);

      // Once-and-persist: the seeded set is written back immediately.
      expect(storage.getString('main_lang'), 'cs');
      expect(storage.getString('active_lang'), 'cs');
      expect(storage.getString('second_lang'), isNull);
    });

    test('unsupported device language de -> main en + banner flag', () async {
      final (lang, _, _, _) = await boot(deviceLocale: const Locale('de'));

      expect(lang.mainLang, AppLanguage.en);
      expect(lang.secondLang, isNull);
      expect(lang.language, AppLanguage.en);
      expect(lang.deviceLangUnsupported, isTrue);
      expect(lang.deviceLocale, const Locale('de'));
    });

    test('null device locale -> main en, no banner flag', () async {
      final (lang, _, _, _) = await boot();

      expect(lang.mainLang, AppLanguage.en);
      expect(lang.language, AppLanguage.en);
      expect(lang.deviceLangUnsupported, isFalse);
      expect(lang.deviceLocale, isNull);
    });
  });

  group('LanguageController · once-and-persist (Q16)', () {
    test('a second load ignores a changed device locale', () async {
      // First run seeds cs from the device and persists it.
      await boot(deviceLocale: const Locale('cs'));

      // A new controller (app restart) over the same storage with a *changed*
      // device locale must not move the seeded set.
      SharedPreferences.setMockInitialValues({
        'main_lang': 'cs',
        'active_lang': 'cs',
      });
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);
      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)
        ..load(deviceLocale: const Locale('de'));

      expect(lang.mainLang, AppLanguage.cs);
      expect(lang.language, AppLanguage.cs);
    });
  });

  group('LanguageController · active language restore (Q17)', () {
    test('stored active language is restored when inside the set',
        () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'cs',
        'second_lang': 'en',
        'active_lang': 'en',
      });

      expect(lang.mainLang, AppLanguage.cs);
      expect(lang.secondLang, AppLanguage.en);
      expect(lang.language, AppLanguage.en);
    });

    test('stored active outside the set snaps to main', () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'uk',
      });

      expect(lang.language, AppLanguage.en);
    });

    test('missing active snaps to main', () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'uk',
      });

      // Absent active_lang restores as `en` (fromKey fallback), which is
      // outside the single-language set [uk] — snaps to main.
      expect(lang.language, AppLanguage.uk);
    });

    test('unrecognized second_lang value reads as absent (none)', () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'garbage',
      });

      expect(lang.secondLang, isNull);
      expect(lang.set, [AppLanguage.en]);
    });
  });

  group('LanguageController · swap on setMainLang (Q12)', () {
    test('setMainLang to the current second language swaps the set',
        () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });

      lang.setMainLang(AppLanguage.cs);

      expect(lang.mainLang, AppLanguage.cs);
      expect(lang.secondLang, AppLanguage.en);
      expect(lang.set, [AppLanguage.cs, AppLanguage.en]);
    });

    test('active language is preserved by a swap (still in set)', () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'en',
      });

      lang.setMainLang(AppLanguage.cs); // swaps: main=cs, second=en

      expect(lang.language, AppLanguage.en);
    });

    test('non-conflicting main change orphans active -> snaps to new main',
        () async {
      final (lang, _, _, _) = await boot(); // single en, active en

      lang.setMainLang(AppLanguage.uk);

      expect(lang.mainLang, AppLanguage.uk);
      expect(lang.secondLang, isNull);
      expect(lang.language, AppLanguage.uk);
    });
  });

  group('LanguageController · setSecondEnabled', () {
    test('enabling after off defaults to the first supported != main (Q18)',
        () async {
      final (lang, _, _, _) = await boot(); // single en

      lang.setSecondEnabled(true);

      expect(lang.secondLang, AppLanguage.cs); // values order: en, cs, uk
      expect(lang.set, [AppLanguage.en, AppLanguage.cs]);
    });

    test('enabling with main=cs defaults to en', () async {
      final (lang, _, _, _) =
          await boot(deviceLocale: const Locale('cs')); // single cs

      lang.setSecondEnabled(true);

      expect(lang.secondLang, AppLanguage.en);
    });

    test('disabling while second is active snaps active to main, clears '
        'the sentence, stops speech (single notify)', () async {
      final (lang, _, composer, tts) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'cs',
      });

      composer.addChar('a');
      composer.addChar('h');
      composer.addChar('o');
      expect(composer.text, 'aho');

      final callsBefore = tts.calls.length;
      var notifyCount = 0;
      lang.addListener(() => notifyCount++);

      lang.setSecondEnabled(false);

      expect(lang.secondLang, isNull);
      expect(lang.language, AppLanguage.en); // snapped to main
      expect(composer.text, ''); // sentence cleared, §6.1.1
      expect(notifyCount, 1,
          reason: 'the disable path delegates the snap to setLanguage(), '
              'which already notifies — it must not also notify itself');
      expect(
        tts.calls.skip(callsBefore).any((c) => c.method == 'stop'),
        isTrue,
        reason: 'switching the active language back to main cancels speech',
      );
    });

    test('disabling while main is active removes the second_lang key',
        () async {
      final (lang, storage, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'en',
      });

      var notifyCount = 0;
      lang.addListener(() => notifyCount++);

      lang.setSecondEnabled(false);

      expect(lang.secondLang, isNull);
      expect(storage.getString('second_lang'), isNull,
          reason: 'absent key = no second language (Q5) — never encoded');
      expect(storage.getString('main_lang'), 'en');
      expect(notifyCount, 1);
    });

    test('re-enabling after a disable starts from the default, not stale',
        () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'en',
      });

      lang.setSecondEnabled(false);
      lang.setSecondEnabled(true);

      // Q18-strict: the old cs must not resurrect via storage.
      expect(lang.secondLang, AppLanguage.cs); // default for main=en
    });
  });

  group('LanguageController · setSecondLang guard', () {
    test('setSecondLang(main) is a defensive no-op', () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });

      var notifyCount = 0;
      lang.addListener(() => notifyCount++);

      lang.setSecondLang(AppLanguage.en);

      expect(lang.mainLang, AppLanguage.en);
      expect(lang.secondLang, AppLanguage.cs);
      expect(notifyCount, 0);
    });

    test('changing the second slot away from active snaps active to main',
        () async {
      final (lang, _, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'cs',
      });

      var notifyCount = 0;
      lang.addListener(() => notifyCount++);

      lang.setSecondLang(AppLanguage.uk); // orphans cs

      expect(lang.set, [AppLanguage.en, AppLanguage.uk]);
      expect(lang.language, AppLanguage.en);
      expect(notifyCount, 1);
    });
  });

  group('LanguageController · persistence round-trip', () {
    test('main/second/active survive a reload from the same storage',
        () async {
      final (lang, storage, _, _) = await boot(deviceLocale: const Locale('cs'));
      lang.setSecondEnabled(true); // second = en (first != main=cs)
      lang.setLanguage(AppLanguage.en); // child flips to the second board

      expect(lang.set, [AppLanguage.cs, AppLanguage.en]);

      // Fresh controller (app restart) over the SAME store — no re-seeding:
      // this reads back exactly what the first controller persisted.
      final tts2 = _FakeTts()..install();
      addTearDown(tts2.uninstall);
      final speech2 = SpeechService();
      await speech2.init();
      final lang2 =
          LanguageController(storage, speech2, ComposerController())..load();

      expect(lang2.mainLang, AppLanguage.cs);
      expect(lang2.secondLang, AppLanguage.en);
      expect(lang2.language, AppLanguage.en);
      expect(lang2.set, [AppLanguage.cs, AppLanguage.en]);
    });

    test('a disable survives a reload (no stale resurrection, Q18)',
        () async {
      final (lang, storage, _, _) = await boot(prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'cs',
      });
      lang.setSecondEnabled(false);
      expect(lang.secondLang, isNull);

      // Fresh controller over the SAME store: the removed key stays removed.
      final tts2 = _FakeTts()..install();
      addTearDown(tts2.uninstall);
      final speech2 = SpeechService();
      await speech2.init();
      final lang2 =
          LanguageController(storage, speech2, ComposerController())..load();

      expect(lang2.secondLang, isNull);
      expect(lang2.set, [AppLanguage.en]);
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
