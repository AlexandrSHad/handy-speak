import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/data/phrases_data.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/services/telemetry_service.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Unit coverage for StorageService's write seam and init-time migration
// (R1 C3, S02-issue-C3 items 2–3): every setString/setBool/remove failure
// routes to the `storage/write` scope with the KEY as the only tag — never
// the value, which can be a parent-entered phrase (ADR-0004 canary below)
// — and the migration runs inside init() version-last: a failed
// step-write leaves the marker unwritten and the next init converges.
// Since PR #15 round one: also the corrupt-blob quarantine pins —
// PhrasesController's load-failure path driven over this same fake disk,
// the environment the gatekeeper verified against the actual plugin.
//
// Failing writes need the write to fail at the plugin level, so these
// suites mock the `plugins.flutter.io/shared_preferences` method channel
// (the same mechanics as the harness's FakeTts) instead of
// `setMockInitialValues`, whose in-memory store never fails.

const MethodChannel _prefsChannel =
    MethodChannel('plugins.flutter.io/shared_preferences');

/// The fake "disk" behind the channel: `getAll` reads it, `set*`/`remove`
/// write it — and every write fails while [failWrites] is set, exactly
/// like a full or broken SharedPreferences backend. [failCorruptWrites]
/// fails only the `.corrupt` quarantine writes.
class _FakeDisk {
  final Map<String, Object> data = {};
  bool failWrites = false;
  bool failCorruptWrites = false;

  bool _shouldFail(String key) =>
      failWrites || (failCorruptWrites && key.endsWith('.corrupt'));

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getAll':
        return data;
      case 'remove':
        final key = (call.arguments as Map)['key'] as String;
        if (_shouldFail(key)) throw PlatformException(code: 'test-io');
        data.remove(key);
        return true;
      default:
        // setString / setBool / setInt — the plugin prefixes keys itself.
        final args = call.arguments as Map;
        final key = args['key'] as String;
        if (_shouldFail(key)) throw PlatformException(code: 'test-io');
        data[key] = args['value'] as Object;
        return true;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDisk disk;
  late TelemetryService telemetry;

  setUp(() async {
    // Without setMockInitialValues the store platform stays the real
    // method-channel one, so the mock handler above sees every call.
    // resetStatic drops the memoized instance so each test re-reads getAll.
    SharedPreferences.resetStatic();
    disk = _FakeDisk();
    telemetry = TelemetryService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_prefsChannel, disk.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_prefsChannel, null);
  });

  test('a failing setString captures storage/write with the key, never the '
      'value (ADR-0004 canary)', () async {
    final storage = StorageService(telemetry: telemetry);
    await storage.init(); // marks the fresh store v2
    expect(telemetry.capturedErrors, isEmpty);

    disk.failWrites = true;
    const value = 'CANARYQQ7X a parent-entered phrase';
    await expectLater(
      storage.setString('phrases_en', value),
      throwsA(anything), // the failure still propagates to awaiting callers
    );
    // The capture is fire-and-forget — let it land before asserting.
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.capturedErrors, hasLength(1));
    final captured = telemetry.capturedErrors.single;
    expect(captured.scope, 'storage/write');
    expect(captured.tags.keys, {'storage_key'});
    expect(captured.tags['storage_key'], 'phrases_en');
    final serialized =
        '${captured.message}${captured.stackTrace}${captured.tags}'
        '${captured.extras}';
    expect(serialized.contains('CANARYQQ7X'), isFalse,
        reason: 'the written VALUE must never reach telemetry — key only');
  });

  test('failing setBool and remove route through the same scope', () async {
    final storage = StorageService(telemetry: telemetry);
    await storage.init();

    disk.failWrites = true;
    await expectLater(
        storage.setBool('dark_mode', true), throwsA(anything));
    await expectLater(storage.remove('second_lang'), throwsA(anything));
    await Future<void>.delayed(Duration.zero);

    final scopes = telemetry.capturedErrors.map((e) => e.scope).toList();
    expect(scopes, ['storage/write', 'storage/write']);
    expect(
      telemetry.capturedErrors.map((e) => e.tags['storage_key']),
      ['dark_mode', 'second_lang'],
    );
  });

  test('successful writes capture nothing', () async {
    final storage = StorageService(telemetry: telemetry);
    await storage.init();

    await storage.setString('phrases_en', '[{"id":0,"text":"Hi",'
        '"pinned":false}]');
    await storage.setBool('dark_mode', true);
    await storage.remove('dark_mode');
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.capturedErrors, isEmpty);
  });

  test('init migrates a v1 store before any reader sees it', () async {
    disk.data['flutter.phrases_en'] =
        '[{"text":"Hi","pinned":false,"uses":9}]';

    final storage = StorageService(telemetry: telemetry);
    await storage.init();

    expect(storage.getString('phrases_en'),
        '[{"text":"Hi","pinned":false,"id":0}]');
    expect(disk.data['flutter.schema_version'], 2);
  });

  test('a failed migration write leaves the marker unwritten '
      '(version-last) and the next init converges', () async {
    const v1 = '[{"text":"Hi","pinned":false,"uses":9}]';
    disk.data['flutter.phrases_en'] = v1;
    disk.failWrites = true;

    final first = StorageService(telemetry: telemetry);
    await expectLater(first.init(), throwsA(anything));
    await Future<void>.delayed(Duration.zero);

    // Nothing was committed to disk: the version marker is absent, and the
    // blob is byte-identical to what a support path would need to see.
    expect(disk.data.containsKey('flutter.schema_version'), isFalse);
    expect(disk.data['flutter.phrases_en'], v1);
    // The migration write itself is not the write seam's business — it is
    // an init failure, surfaced to main.dart's storage/init handler.
    expect(telemetry.capturedErrors, isEmpty);

    // Next boot: writes succeed again — the interrupted migration re-runs
    // and converges, exactly the crash-safety rule S02 prescribes.
    disk.failWrites = false;
    SharedPreferences.resetStatic();
    final second = StorageService(telemetry: telemetry);
    await second.init();

    expect(disk.data['flutter.phrases_en'],
        '[{"text":"Hi","pinned":false,"id":0}]');
    expect(disk.data['flutter.schema_version'], 2);
  });

  group('PhrasesController · corrupt-blob quarantine (PR #15 round 1)', () {
    // The round-1 blocking-fix pins, at controller level, over this file's
    // channel-level disk — the faithful environment for exactly what the
    // gatekeeper verified: the real plugin (shared_preferences 2.5.5)
    // mutates its Dart-side cache synchronously BEFORE the platform call,
    // so a rejected setString leaves the in-process cache looking written
    // while the disk never saw it. Assertions therefore go to the disk map
    // (what a reboot actually reads), and every boot below is a full
    // next-boot: resetStatic + fresh instances re-reading getAll.
    Future<(PhrasesController, StorageService)> bootController() async {
      SharedPreferences.resetStatic();
      final storage = StorageService(telemetry: telemetry);
      await storage.init();
      return (
        PhrasesController(storage, telemetry: telemetry)..load(),
        storage
      );
    }

    test('a failed backup leaves the original key on disk and the remove '
        'unissued', () async {
      const raw = 'this is not json {{{';
      disk.data['flutter.phrases_en'] = raw;
      disk.failCorruptWrites = true;

      final (phrases, _) = await bootController();
      await Future<void>.delayed(Duration.zero); // let the chain settle

      // The backup never reached the disk…
      expect(disk.data.containsKey('flutter.phrases_en.corrupt'), isFalse);
      // …so the remove was never issued: the original key — the only
      // surviving copy — is still there and readable by the next boot.
      // (The plugin's in-process cache claims the backup happened; the
      // disk is the truth a reboot reads.)
      expect(disk.data['flutter.phrases_en'], raw);
      expect(phrases.saveFailed, isTrue);
    });

    test('a mutation while quarantined does NOT overwrite the original key',
        () async {
      const raw = 'this is not json {{{';
      disk.data['flutter.phrases_en'] = raw;
      disk.failCorruptWrites = true;
      final (phrases, _) = await bootController();
      await Future<void>.delayed(Duration.zero);

      phrases.add(AppLanguage.en, 'edit while quarantined');
      await Future<void>.delayed(Duration.zero);

      // The edit is visible in memory (the list re-seeded, plus the row)…
      expect(phrases.phrasesFor(AppLanguage.en).map((p) => p.text),
          contains('edit while quarantined'));
      // …but the store was not written: a re-seeded blob would overwrite
      // the only surviving copy of the parent's content.
      expect(disk.data['flutter.phrases_en'], raw);
      expect(disk.data.containsKey('flutter.phrases_en.corrupt'), isFalse);
    });

    test('saveFailed holds while quarantined and clears only via a next '
        'boot with a working backup', () async {
      const raw = 'this is not json {{{';
      disk.data['flutter.phrases_en'] = raw;

      // Boot 1: the backup fails — quarantined, banner up.
      disk.failCorruptWrites = true;
      final (first, _) = await bootController();
      await Future<void>.delayed(Duration.zero);
      expect(first.saveFailed, isTrue);

      // Boot 2 (fresh instances, same disk): the backup still fails — the
      // state does not silently clear, and the original key survives.
      final (second, _) = await bootController();
      await Future<void>.delayed(Duration.zero);
      expect(second.saveFailed, isTrue);
      expect(disk.data['flutter.phrases_en'], raw);

      // Boot 3 (backup healthy): the quarantine completes — the key is
      // dropped, the copy exists, the banner is down.
      disk.failCorruptWrites = false;
      final (third, _) = await bootController();
      await Future<void>.delayed(Duration.zero);
      expect(third.saveFailed, isFalse);
      expect(disk.data.containsKey('flutter.phrases_en'), isFalse);
      expect(disk.data['flutter.phrases_en.corrupt'], raw);
      expect(third.phrasesFor(AppLanguage.en),
          hasLength(kSeedPhrases[AppLanguage.en]!.length));
    });
  });
}

