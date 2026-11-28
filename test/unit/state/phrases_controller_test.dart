import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/data/phrases_data.dart';
import 'package:handy_speak/services/storage_keys.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/services/telemetry_service.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Unit coverage for PhrasesController (testing-strategy §4 "Saved phrases"):
// the per-language store — pinned-first/insertion ordering (M2, owner
// decision 2026-11-28: the never-incremented `uses` counter no longer
// sorts), first-run seeding vs restore-from-storage, v2 JSON round-trip
// with stable ids (M5), the v1→v2 migration running before load, corruption
// fallback to the seed with a `.corrupt` backup, id-based remove/toggle
// (same-text phrases are distinct), empty-add rejection, the transient
// save-failure state, and the debug round-trip check. Boots a loaded
// controller over fresh mock storage; no widget tree, no TTS (this
// controller never speaks).

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // A loaded controller over fresh mock storage. [prefs] seeds the store
  // *before* init/load — key presence (`phrases_<lang>`) decides seed vs
  // restore, and init() runs the schema migration first (as in main.dart).
  Future<(PhrasesController, StorageService)> boot({
    Map<String, Object> prefs = const {},
    TelemetryService? telemetry,
    StorageService? storage,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final s = storage ?? StorageService();
    await s.init();
    final phrases = PhrasesController(s, telemetry: telemetry)..load();
    return (phrases, s);
  }

  String encode(List<Phrase> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  group('PhrasesController · ordering', () {
    test('pinned phrases sort ahead of unpinned', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'unpinned', pinned: false),
          Phrase(id: 1, text: 'pinned', pinned: true),
        ]),
      });

      final list = phrases.phrasesFor(AppLanguage.en);
      expect(list.first.text, 'pinned');
      expect(list.last.text, 'unpinned');
    });

    test('within a pin group phrases keep their insertion order (M2: the '
        'uses sort is gone)', () async {
      // The pre-M2 contract sorted each pin group by uses descending
      // (['p-high', 'p-low', 'u-high', 'u-low']); the owner decision
      // (2026-11-28) replaced it with stable insertion order.
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'p-low', pinned: true),
          Phrase(id: 1, text: 'p-high', pinned: true),
          Phrase(id: 2, text: 'u-low', pinned: false),
          Phrase(id: 3, text: 'u-high', pinned: false),
        ]),
      });

      expect(
        phrases.phrasesFor(AppLanguage.en).map((p) => p.text).toList(),
        ['p-low', 'p-high', 'u-low', 'u-high'],
      );
    });

    test('phrasesFor returns a copy — the internal list is not reordered',
        () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'a', pinned: false),
          Phrase(id: 1, text: 'b', pinned: true),
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

    test('seeded phrases carry unique, stable ids (M5)', () async {
      final (phrases, _) = await boot();

      final ids = phrases
          .phrasesFor(AppLanguage.en)
          .map((p) => p.id)
          .toSet();
      expect(ids, hasLength(kSeedPhrases[AppLanguage.en]!.length));
    });

    test('a stored list is restored verbatim, not re-seeded', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'only-me', pinned: true),
        ]),
      });

      final list = phrases.phrasesFor(AppLanguage.en);
      expect(list, hasLength(1));
      expect(list.single.text, 'only-me');
      expect(list.single.id, 0);
    });

    test('a v1 blob (uses, no ids) is migrated before load — restored with '
        'ids, uses gone', () async {
      // If the migration did NOT run before load(), fromJson would throw
      // on the missing id and the list would silently re-seed — so
      // restoring proves the init()-before-load() ordering.
      final (phrases, _) = await boot(prefs: {
        'phrases_en': '[{"text":"legacy","pinned":true,"uses":7}]',
      });

      final list = phrases.phrasesFor(AppLanguage.en);
      expect(list, hasLength(1));
      expect(list.single.text, 'legacy');
      expect(list.single.id, 0);
    });

    test('per-language stores are independent — cs restore leaves en seeded',
        () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_cs': encode(const [
          Phrase(id: 0, text: 'jen cesky', pinned: false),
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

    test('the corrupt blob is quarantined to .corrupt and the key dropped '
        '(S02 item 4)', () async {
      const raw = 'this is not json {{{';
      final (phrases, storage) = await boot(prefs: {'phrases_en': raw});

      // Backup happened BEFORE the re-seeding overwrote anything…
      expect(storage.getString(phrasesCorruptKey(AppLanguage.en)), raw);
      // …and the original key is gone, so the next boot seeds instead of
      // re-reporting the same corruption.
      expect(storage.getString(phrasesKey(AppLanguage.en)), isNull);
      // The in-memory list still fell back to the seeds.
      expect(phrases.phrasesFor(AppLanguage.en),
          hasLength(kSeedPhrases[AppLanguage.en]!.length));
    });

    test('corruption captures phrases/load_corrupt — type + tags only, no '
        'stored content anywhere (ADDENDUM-06)', () async {
      const raw = 'this is not json {{{ CANARYQQ7X';
      final telemetry = TelemetryService();
      final (phrases, _) = await boot(
        prefs: {'phrases_en': raw},
        telemetry: telemetry,
      );

      // The fallback still stands.
      expect(phrases.phrasesFor(AppLanguage.en),
          hasLength(kSeedPhrases[AppLanguage.en]!.length));

      expect(telemetry.capturedErrors, hasLength(1));
      final captured = telemetry.capturedErrors.single;
      expect(captured.scope, 'phrases/load_corrupt');
      expect(captured.exceptionType, 'FormatException');
      // FormatException's message echoes the offending source — suppressed.
      expect(captured.message, '[suppressed by scope policy]');
      expect(captured.stackTrace, isNull);
      expect(captured.tags['phrases_lang'], 'en');
      expect(captured.tags['raw_length'], raw.length.toString());

      final serialized = '${captured.message}${captured.stackTrace}'
          '${captured.tags}${captured.extras}';
      expect(serialized.contains('CANARYQQ7X'), isFalse);
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

    test('add assigns ids above the list\'s highest id (M5)', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 5, text: 'existing', pinned: false),
        ]),
      });

      phrases.add(AppLanguage.en, 'first added');
      phrases.add(AppLanguage.en, 'second added');

      final ids =
          phrases.phrasesFor(AppLanguage.en).map((p) => p.id).toSet();
      expect(ids, containsAll([5, 6, 7]));
    });

    test('a blank / whitespace-only add is rejected', () async {
      final (phrases, _) = await boot(prefs: {'phrases_en': encode(const [])});

      phrases.add(AppLanguage.en, '');
      phrases.add(AppLanguage.en, '   ');

      expect(phrases.phrasesFor(AppLanguage.en), isEmpty);
    });
  });

  group('PhrasesController · remove & togglePin (id identity, M5)', () {
    test('remove drops the matching phrase and leaves the rest', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'keep', pinned: true),
          Phrase(id: 1, text: 'drop', pinned: true),
        ]),
      });

      phrases.remove(
          AppLanguage.en, const Phrase(id: 1, text: 'drop', pinned: true));

      expect(phrases.phrasesFor(AppLanguage.en).map((p) => p.text),
          ['keep']);
    });

    test('remove drops exactly ONE of two same-text phrases', () async {
      // The pre-M5 contract removed every same-text phrase at once.
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'same words', pinned: true),
          Phrase(id: 1, text: 'same words', pinned: false),
        ]),
      });

      phrases.remove(
          AppLanguage.en, const Phrase(id: 0, text: 'same words'));

      final list = phrases.phrasesFor(AppLanguage.en);
      expect(list, hasLength(1));
      expect(list.single.id, 1);
    });

    test('togglePin flips the pinned flag of the matching phrase', () async {
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'flip-me', pinned: false),
          Phrase(id: 1, text: 'leave-me', pinned: false),
        ]),
      });

      phrases.togglePin(
          AppLanguage.en, const Phrase(id: 0, text: 'flip-me'));

      final byText = {
        for (final p in phrases.phrasesFor(AppLanguage.en)) p.text: p.pinned,
      };
      expect(byText['flip-me'], isTrue);
      expect(byText['leave-me'], isFalse);
    });

    test('togglePin addresses exactly one of two same-text phrases', () async {
      // The pre-M5 contract toggled the FIRST text match, whichever row
      // the parent actually tapped.
      final (phrases, _) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'same words', pinned: false),
          Phrase(id: 1, text: 'same words', pinned: false),
        ]),
      });

      phrases.togglePin(
          AppLanguage.en, const Phrase(id: 1, text: 'same words'));

      // Assert by id: phrasesFor reorders (pinned-first), so list position
      // is not the storage position.
      final byId = {
        for (final p in phrases.phrasesFor(AppLanguage.en)) p.id: p.pinned,
      };
      expect(byId[0], isFalse); // untouched
      expect(byId[1], isTrue); // the addressed one — flipped
    });
  });

  group('PhrasesController · persistence round-trip', () {
    // Lets the serialized persist pipeline finish before the "restart"
    // below reads the store.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('an add survives a reload from the same storage, id included',
        () async {
      final (phrases, storage) =
          await boot(prefs: {'phrases_cs': encode(const [])});

      phrases.add(AppLanguage.cs, 'Ahoj');
      await settle();

      // Fresh controller (app restart) over the SAME store — no re-seeding.
      final reloaded = PhrasesController(storage)..load();
      final list = reloaded.phrasesFor(AppLanguage.cs);
      expect(list, hasLength(1));
      expect(list.single.text, 'Ahoj');
      expect(list.single.pinned, isTrue);
      expect(list.single.id, phrases.phrasesFor(AppLanguage.cs).single.id);
    });

    test('a togglePin survives a reload', () async {
      final (phrases, storage) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'x', pinned: false),
        ]),
      });

      phrases.togglePin(AppLanguage.en, const Phrase(id: 0, text: 'x'));
      await settle();

      final reloaded = PhrasesController(storage)..load();
      expect(reloaded.phrasesFor(AppLanguage.en).single.pinned, isTrue);
    });

    test('a remove survives a reload', () async {
      final (phrases, storage) = await boot(prefs: {
        'phrases_en': encode(const [
          Phrase(id: 0, text: 'gone', pinned: true),
        ]),
      });

      phrases.remove(AppLanguage.en, const Phrase(id: 0, text: 'gone'));
      await settle();

      final reloaded = PhrasesController(storage)..load();
      expect(reloaded.phrasesFor(AppLanguage.en), isEmpty);
    });
  });

  group('PhrasesController · save-failure state (S02 item 3)', () {
    test('a failed persist exposes saveFailed; the next successful persist '
        'clears it — notifying only on transitions', () async {
      final storage = _FlakyPhrasesStorage()..failPhrasesWrites = 2;
      final (phrases, _) = await boot(
        prefs: {'phrases_en': encode(const [])},
        storage: storage,
      );
      expect(phrases.saveFailed, isFalse);

      var notifications = 0;
      phrases.addListener(() => notifications++);

      phrases.add(AppLanguage.en, 'one'); // persist fails (#1)
      await Future<void>.delayed(Duration.zero);
      expect(phrases.saveFailed, isTrue);
      expect(notifications, 2, reason: 'the add + the false→true transition');

      phrases.add(AppLanguage.en, 'two'); // persist fails (#2) — no change
      await Future<void>.delayed(Duration.zero);
      expect(phrases.saveFailed, isTrue);
      expect(notifications, 3, reason: 'the add only — no re-notify');

      phrases.add(AppLanguage.en, 'three'); // persist succeeds
      await Future<void>.delayed(Duration.zero);
      expect(phrases.saveFailed, isFalse);
      expect(notifications, 5, reason: 'the add + the true→false transition');
    });

    test('the in-memory edit survives a failed save — the next successful '
        'persist writes it too', () async {
      final storage = _FlakyPhrasesStorage()..failPhrasesWrites = 1;
      final (phrases, s) = await boot(
        prefs: {'phrases_en': encode(const [])},
        storage: storage,
      );

      phrases.add(AppLanguage.en, 'kept despite the failure');
      await Future<void>.delayed(Duration.zero);
      expect(phrases.saveFailed, isTrue);

      phrases.add(AppLanguage.en, 'second edit');
      await Future<void>.delayed(Duration.zero);
      expect(phrases.saveFailed, isFalse);

      // The whole list (both edits) landed on the successful persist.
      final reloaded = PhrasesController(s)..load();
      expect(reloaded.phrasesFor(AppLanguage.en).map((p) => p.text),
          containsAll(['kept despite the failure', 'second edit']));
    });
  });

  group('PhrasesController · debug round-trip check (S02 item 5)', () {
    test('a round-trip mismatch after a successful write debugPrints '
        '(lengths only, never content)', () async {
      final prints = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          prints.add(message ?? '');
      addTearDown(() => debugPrint = original);

      final storage = _RoundTripBreakingStorage()..breakRoundTrip = true;
      final (phrases, _) = await boot(
        prefs: {'phrases_en': encode(const [])},
        storage: storage,
      );

      phrases.add(AppLanguage.en, 'Can I play');
      await Future<void>.delayed(Duration.zero);

      expect(prints, hasLength(1));
      expect(prints.single, contains('round-trip mismatch'));
      expect(prints.single, contains('phrases_en'));
      // ADR-0004 posture even on the local console: lengths, not content.
      expect(prints.single.contains('Can I play'), isFalse);
      // A mismatch is NOT a save failure — the write itself succeeded.
      expect(phrases.saveFailed, isFalse);
    });
  });
}

/// A [StorageService] whose phrase-blob writes fail on demand — drives the
/// save-failure state end-to-end. Everything else (the migration inside
/// init, other keys) goes through the real seam.
class _FlakyPhrasesStorage extends StorageService {
  /// When > 0, the next phrase-blob `setString` calls fail (decremented
  /// per failure).
  int failPhrasesWrites = 0;

  @override
  Future<void> setString(String key, String value) {
    if (key.startsWith('phrases_') && failPhrasesWrites > 0) {
      failPhrasesWrites--;
      throw Exception('simulated storage failure');
    }
    return super.setString(key, value);
  }
}

/// A [StorageService] whose writes succeed but whose store then reads back
/// garbage — drives the debug round-trip check (S02 item 5). The write
/// itself never fails, so the banner path stays out of the picture.
class _RoundTripBreakingStorage extends StorageService {
  bool breakRoundTrip = false;
  String? _corrupted;

  @override
  Future<void> setString(String key, String value) async {
    await super.setString(key, value);
    if (breakRoundTrip) _corrupted = 'garbage, not the blob';
  }

  @override
  String? getString(String key) => _corrupted ?? super.getString(key);
}
