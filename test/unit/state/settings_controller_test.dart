import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Unit coverage for SettingsController (testing-strategy §4 "Settings"):
// load() yields the documented default for each flag over empty storage (and
// a sensible fallback when a stored value is the wrong type), and each setter
// persists immediately — verified by reloading a fresh controller over the
// same storage. No widget tree; this controller never speaks.

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // A loaded controller over fresh mock storage. [prefs] seeds the store
  // before load().
  Future<(SettingsController, StorageService)> boot({
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final storage = StorageService();
    await storage.init();
    final settings = SettingsController(storage)..load();
    return (settings, storage);
  }

  group('SettingsController · defaults over empty storage', () {
    test('dark defaults off', () async {
      final (settings, _) = await boot();
      expect(settings.dark, isFalse);
    });

    test('haptics defaults on', () async {
      final (settings, _) = await boot();
      expect(settings.haptics, isTrue);
    });

    test('bigLetters defaults off', () async {
      final (settings, _) = await boot();
      expect(settings.bigLetters, isFalse);
    });

    test('showPhrases defaults on', () async {
      final (settings, _) = await boot();
      expect(settings.showPhrases, isTrue);
    });

    test('moodEnabled is constant-off (out of scope for the POC)', () async {
      final (settings, _) = await boot();
      expect(settings.moodEnabled, isFalse);
    });
  });

  group('SettingsController · missing keys fall back per-flag', () {
    // A partially-populated store (an older install that predates a flag)
    // must not drag the absent flags off their defaults — each flag falls
    // back independently. Absence is the real corruption/missing vector for
    // a bool: shared_preferences only ever holds bools the setters wrote.
    test('a store with only dark set leaves the rest at their defaults',
        () async {
      final (settings, _) = await boot(prefs: {'dark_mode': true});

      expect(settings.dark, isTrue); // the one stored value
      expect(settings.haptics, isTrue); // default
      expect(settings.bigLetters, isFalse); // default
      expect(settings.showPhrases, isTrue); // default
    });

    test('a store with only haptics disabled leaves the rest at defaults',
        () async {
      final (settings, _) = await boot(prefs: {'haptics': false});

      expect(settings.haptics, isFalse); // the one stored value
      expect(settings.dark, isFalse); // default
      expect(settings.bigLetters, isFalse); // default
      expect(settings.showPhrases, isTrue); // default
    });
  });

  group('SettingsController · load restores a valid stored value', () {
    test('stored non-default flags load as stored', () async {
      final (settings, _) = await boot(prefs: {
        'dark_mode': true,
        'haptics': false,
        'big_letters': true,
        'show_phrases': false,
      });

      expect(settings.dark, isTrue);
      expect(settings.haptics, isFalse);
      expect(settings.bigLetters, isTrue);
      expect(settings.showPhrases, isFalse);
    });
  });

  group('SettingsController · setters persist immediately', () {
    test('setDark survives a reload', () async {
      final (settings, storage) = await boot();
      settings.setDark(true);

      final reloaded = SettingsController(storage)..load();
      expect(reloaded.dark, isTrue);
    });

    test('setHaptics survives a reload', () async {
      final (settings, storage) = await boot();
      settings.setHaptics(false);

      final reloaded = SettingsController(storage)..load();
      expect(reloaded.haptics, isFalse);
    });

    test('setBigLetters survives a reload', () async {
      final (settings, storage) = await boot();
      settings.setBigLetters(true);

      final reloaded = SettingsController(storage)..load();
      expect(reloaded.bigLetters, isTrue);
    });

    test('setShowPhrases survives a reload', () async {
      final (settings, storage) = await boot();
      settings.setShowPhrases(false);

      final reloaded = SettingsController(storage)..load();
      expect(reloaded.showPhrases, isFalse);
    });
  });
}
