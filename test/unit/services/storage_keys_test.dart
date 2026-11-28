import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/services/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Unit coverage for the storage schema module (R1 C3, S02-issue-C3 items
// 1–2): the pure v1→v2 migration step — id assignment (M5), `uses`
// stripping (M2), idempotency, corrupt-blob pass-through — and the
// version-last runner: fresh-install marking, interrupted-migration
// convergence, and the newer-store guard.

void main() {
  // A fresh SharedPreferences over seeded [prefs] — the same instance
  // shape `StorageService.init()` hands to [runMigrations].
  Future<SharedPreferences> boot(
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    return SharedPreferences.getInstance();
  }

  group('migratePhrasesBlobV1toV2 · pure step', () {
    test('assigns sequential ids to v1 entries and strips uses', () {
      const raw =
          '[{"text":"Hello","pinned":true,"uses":42},{"text":"Bye",'
          '"pinned":false,"uses":0}]';

      final migrated = migratePhrasesBlobV1toV2(raw)!;

      final list = jsonDecode(migrated) as List;
      expect(list, hasLength(2));
      expect(list[0], {'text': 'Hello', 'pinned': true, 'id': 0});
      expect(list[1], {'text': 'Bye', 'pinned': false, 'id': 1});
    });

    test('new ids continue above the highest existing id (no collisions)',
        () {
      const raw = '[{"id":5,"text":"A","pinned":false},{"text":"B",'
          '"pinned":false},{"id":2,"text":"C","pinned":true}]';

      final migrated = migratePhrasesBlobV1toV2(raw)!;

      final entries = (jsonDecode(migrated) as List).cast<Map>();
      final ids = entries.map((e) => e['id'] as int).toSet();
      expect(ids, hasLength(3)); // all distinct
      expect(ids, containsAll([5, 2])); // surviving ids untouched
      // The id-less entry landed above the highest surviving id.
      expect(ids.where((id) => id > 5), isNotEmpty);
    });

    test('is idempotent — migrating its own output is a byte-equal no-op',
        () {
      const raw = '[{"text":"Hello","pinned":true,"uses":42}]';
      final once = migratePhrasesBlobV1toV2(raw)!;
      expect(once, isNot(raw));
      expect(migratePhrasesBlobV1toV2(once), once);
    });

    test('preserves unknown fields (forward compatibility)', () {
      const raw =
          '[{"text":"A","pinned":false,"mood":"cheerful","uses":1}]';

      final migrated = migratePhrasesBlobV1toV2(raw)!;

      final entry = (jsonDecode(migrated) as List).single as Map;
      expect(entry['mood'], 'cheerful');
      expect(entry.containsKey('uses'), isFalse);
    });

    test('returns null for anything Phrase.fromJson could not decode', () {
      const corrupt = [
        'this is not json {{{',
        '{"not":"a list"}',
        '"just a string"',
        '[42]',
        '[{"text":42}]',
        '[{"text":"A","pinned":"yes"}]',
        '[{"id":"x","text":"A"}]',
      ];
      for (final raw in corrupt) {
        expect(migratePhrasesBlobV1toV2(raw), isNull,
            reason: 'expected null for: $raw');
      }
    });
  });

  group('runMigrations', () {
    test('a fresh store is marked v2 and nothing else is written', () async {
      final prefs = await boot();

      await runMigrations(prefs);

      expect(prefs.getInt(kSchemaVersionKey), kSchemaVersion);
      expect(prefs.getKeys(), {kSchemaVersionKey});
    });

    test('a v1 store: blobs gain ids and lose uses, version written',
        () async {
      final prefs = await boot(prefs: {
        'phrases_en': '[{"text":"Hi","pinned":false,"uses":9}]',
        'main_lang': 'en',
      });

      await runMigrations(prefs);

      expect(prefs.getInt(kSchemaVersionKey), kSchemaVersion);
      expect(prefs.getString('phrases_en'),
          '[{"text":"Hi","pinned":false,"id":0}]');
      // Non-phrase keys are v1→v2 invariant: same name, same shape.
      expect(prefs.getString('main_lang'), 'en');
    });

    test('every language blob is migrated, independently', () async {
      final prefs = await boot(prefs: {
        'phrases_en': '[{"text":"Hi","pinned":false,"uses":1}]',
        'phrases_cs': '[{"text":"Ahoj","pinned":true,"uses":2}]',
        'phrases_uk': '[{"text":"Привіт","pinned":true,"uses":3}]',
      });

      await runMigrations(prefs);

      expect(prefs.getString('phrases_en'),
          '[{"text":"Hi","pinned":false,"id":0}]');
      expect(prefs.getString('phrases_cs'),
          '[{"text":"Ahoj","pinned":true,"id":0}]');
      expect(prefs.getString('phrases_uk'),
          '[{"text":"Привіт","pinned":true,"id":0}]');
      expect(prefs.getInt(kSchemaVersionKey), kSchemaVersion);
    });

    test('corrupt blobs are left byte-identical (quarantine path owns them)',
        () async {
      const raw = 'not json at all {{{';
      final prefs = await boot(prefs: {'phrases_cs': raw});

      await runMigrations(prefs);

      expect(prefs.getString('phrases_cs'), raw);
      // A corrupt blob is not a migration failure — the version still
      // lands; the controller's load path quarantines and re-seeds.
      expect(prefs.getInt(kSchemaVersionKey), kSchemaVersion);
    });

    test('a store already at the current version is untouched', () async {
      // A corrupt blob behind an already-written marker must stay corrupt:
      // the marker says "this store is v2", not "repair me".
      const raw = '{"not":"a list"}';
      final prefs = await boot(prefs: {
        kSchemaVersionKey: kSchemaVersion,
        'phrases_en': raw,
      });

      await runMigrations(prefs);

      expect(prefs.getString('phrases_en'), raw);
      expect(prefs.getInt(kSchemaVersionKey), kSchemaVersion);
    });

    test('converges when re-run after an interrupted migration', () async {
      // Crash between "blob written" and "version written": the store
      // holds migrated blobs but no marker. The re-run must be a no-op on
      // the blobs and write only the marker (idempotent, version-last).
      const migrated = '[{"text":"Hi","pinned":false,"id":0}]';
      final prefs = await boot(prefs: {'phrases_en': migrated});

      await runMigrations(prefs);

      expect(prefs.getString('phrases_en'), migrated);
      expect(prefs.getInt(kSchemaVersionKey), kSchemaVersion);
    });

    test('a store from a newer build is left completely untouched', () async {
      const raw = '[{"text":"future","pinned":false,"uses":7}]';
      final prefs = await boot(prefs: {
        kSchemaVersionKey: 99,
        'phrases_en': raw,
      });

      await runMigrations(prefs);

      expect(prefs.getInt(kSchemaVersionKey), 99);
      expect(prefs.getString('phrases_en'), raw);
    });
  });
}
