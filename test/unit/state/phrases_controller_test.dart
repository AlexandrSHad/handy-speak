import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/data/phrases_data.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Unit coverage for PhrasesController (testing-strategy §4 "Saved phrases"):
// the per-language store — pinned-first/uses-descending ordering, first-run
// seeding vs restore-from-storage, JSON persistence round-trip, corruption
// fallback to the seed, empty-add rejection, and remove/toggle matching the
// right phrase. Boots a loaded controller over fresh mock storage; no widget
// tree, no TTS (this controller never speaks).

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // A loaded controller over fresh mock storage. [prefs] seeds the store
  // *before* load — key presence (`phrases_<lang>`) decides seed vs restore.
  Future<(PhrasesController, StorageService)> boot({
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final storage = StorageService();
    await storage.init();
    final phrases = PhrasesController(storage)..load();
    return (phrases, storage);
  }

  String encode(List<Phrase> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  group('PhrasesController · ordering', () {
    test('pinned phrases sort ahead of unpinned regardless of uses', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'unpinned-hot', pinned: false, uses: 99),
          Phrase(text: 'pinned-cold', pinned: true, uses: 1),
        ]),
      });

      final list = phrases.phrasesFor(AppLanguage.en);
      expect(list.first.text, 'pinned-cold');
      expect(list.last.text, 'unpinned-hot');
    });

    test('within a pin group phrases sort by uses descending', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'p-low', pinned: true, uses: 5),
          Phrase(text: 'p-high', pinned: true, uses: 50),
          Phrase(text: 'u-low', pinned: false, uses: 2),
          Phrase(text: 'u-high', pinned: false, uses: 20),
        ]),
      });

      expect(
        phrases.phrasesFor(AppLanguage.en).map((p) => p.text).toList(),
        ['p-high', 'p-low', 'u-high', 'u-low'],
      );
    });

    test('phrasesFor returns a copy — the internal list is not reordered',
        () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'a', pinned: false, uses: 1),
          Phrase(text: 'b', pinned: true, uses: 1),
        ]),
      });

      final first = phrases.phrasesFor(AppLanguage.en);
      first.clear();
      expect(phrases.phrasesFor(AppLanguage.en), hasLength(2));
    });
  });

  group('PhrasesController · seed vs restore', () {
    test('empty storage seeds each language from kSeedPhrases', () async {
      final (phrases, _) = await boot();

      expect(phrases.phrasesFor(AppLanguage.en),
          hasLength(kSeedPhrases[AppLanguage.en]!.length));
      expect(phrases.phrasesFor(AppLanguage.cs),
          hasLength(kSeedPhrases[AppLanguage.cs]!.length));
      expect(phrases.phrasesFor(AppLanguage.uk),
          hasLength(kSeedPhrases[AppLanguage.uk]!.length));
    });

    test('a stored list is restored verbatim, not re-seeded', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'only-me', pinned: true, uses: 3),
        ]),
      });

      final list = phrases.phrasesFor(AppLanguage.en);
      expect(list, hasLength(1));
      expect(list.single.text, 'only-me');
    });

    test('per-language stores are independent — cs restore leaves en seeded',
        () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_cs': encode(const [
          Phrase(text: 'jen cesky', pinned: false, uses: 0),
        ]),
      });

      expect(phrases.phrasesFor(AppLanguage.cs), hasLength(1));
      expect(phrases.phrasesFor(AppLanguage.en),
          hasLength(kSeedPhrases[AppLanguage.en]!.length));
    });
  });

  group('PhrasesController · corruption fallback', () {
    test('a malformed stored value falls back to the seed without throwing',
        () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': 'this is not json {{{',
      });

      expect(phrases.phrasesFor(AppLanguage.en),
          hasLength(kSeedPhrases[AppLanguage.en]!.length));
    });

    test('valid JSON of the wrong shape also falls back to the seed',
        () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_cs': '{"not":"a list"}',
      });

      expect(phrases.phrasesFor(AppLanguage.cs),
          hasLength(kSeedPhrases[AppLanguage.cs]!.length));
    });
  });

  group('PhrasesController · add', () {
    test('add inserts a pinned phrase and trims whitespace', () async {
      final (phrases, _) = await boot(prefs: {'phrases_uk': encode(const [])});

      phrases.add(AppLanguage.uk, '  Привіт  ');

      final list = phrases.phrasesFor(AppLanguage.uk);
      expect(list, hasLength(1));
      expect(list.single.text, 'Привіт');
      expect(list.single.pinned, isTrue);
    });

    test('a blank / whitespace-only add is rejected', () async {
      final (phrases, _) = await boot(prefs: {'phrases_en': encode(const [])});

      phrases.add(AppLanguage.en, '');
      phrases.add(AppLanguage.en, '   ');

      expect(phrases.phrasesFor(AppLanguage.en), isEmpty);
    });
  });

  group('PhrasesController · remove & togglePin', () {
    test('remove drops the matching phrase and leaves the rest', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'keep', pinned: true, uses: 1),
          Phrase(text: 'drop', pinned: true, uses: 1),
        ]),
      });

      phrases.remove(
          AppLanguage.en, const Phrase(text: 'drop', pinned: true, uses: 1));

      expect(phrases.phrasesFor(AppLanguage.en).map((p) => p.text),
          ['keep']);
    });

    test('togglePin flips the pinned flag of the matching phrase', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'flip-me', pinned: false, uses: 7),
          Phrase(text: 'leave-me', pinned: false, uses: 7),
        ]),
      });

      phrases.togglePin(
          AppLanguage.en, const Phrase(text: 'flip-me', pinned: false, uses: 7));

      final byText = {
        for (final p in phrases.phrasesFor(AppLanguage.en)) p.text: p.pinned,
      };
      expect(byText['flip-me'], isTrue);
      expect(byText['leave-me'], isFalse);
    });
  });

  group('PhrasesController · persistence round-trip', () {
    test('an add survives a reload from the same storage', () async {
      final (phrases, storage) =
          await boot(prefs: {'phrases_cs': encode(const [])});

      phrases.add(AppLanguage.cs, 'Ahoj');

      // Fresh controller (app restart) over the SAME store — no re-seeding.
      final reloaded = PhrasesController(storage)..load();
      final list = reloaded.phrasesFor(AppLanguage.cs);
      expect(list, hasLength(1));
      expect(list.single.text, 'Ahoj');
      expect(list.single.pinned, isTrue);
    });

    test('a togglePin survives a reload', () async {
      final (phrases, storage) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'x', pinned: false, uses: 0),
        ]),
      });

      phrases.togglePin(
          AppLanguage.en, const Phrase(text: 'x', pinned: false, uses: 0));

      final reloaded = PhrasesController(storage)..load();
      expect(reloaded.phrasesFor(AppLanguage.en).single.pinned, isTrue);
    });

    test('a remove survives a reload', () async {
      final (phrases, storage) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(text: 'gone', pinned: true, uses: 1),
        ]),
      });

      phrases.remove(
          AppLanguage.en, const Phrase(text: 'gone', pinned: true, uses: 1));

      final reloaded = PhrasesController(storage)..load();
      expect(reloaded.phrasesFor(AppLanguage.en), isEmpty);
    });
  });
}
