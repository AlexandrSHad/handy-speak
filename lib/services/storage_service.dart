import 'dart:async' show unawaited;

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_keys.dart';
import 'telemetry_service.dart';

/// Thin wrapper over `shared_preferences` (IMPLEMENTATION_PLAN §5).
/// Values are stored as JSON-encoded strings or primitives.
///
/// The one write seam (S02-issue-C3 item 3; policy: ADR-0005): every
/// `setString` / `setBool` / `remove` failure is captured under the
/// `storage/write` telemetry scope with the key name as its only tag —
/// never the value, which can be a parent-entered phrase (ADR-0004). The
/// failure is re-thrown after the capture, so callers that await it (the
/// phrase-save path) can react, while fire-and-forget callers keep
/// today's behaviour — now accompanied by a capture that names the key.
///
/// [init] also runs the schema migrations (`storage_keys.dart`) before it
/// returns, so no controller can `load()` a pre-migration store.
class StorageService {
  StorageService({TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService();

  final TelemetryService _telemetry;
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Before any controller's load() — main.dart awaits init() before the
    // controllers are constructed (S02: an ordering rule, not an
    // assumption). Migration write failures propagate out of init() and
    // surface under `storage/init` in main.dart.
    await runMigrations(_prefs);
  }

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _watch(_prefs.setString(key, value), key);

  bool getBool(String key, {required bool fallback}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> setBool(String key, bool value) =>
      _watch(_prefs.setBool(key, value), key);

  /// Removes [key] entirely. Nullable slots (e.g. the optional second
  /// language, ADDENDUM-04) rely on *absence* meaning "none" — never an
  /// encoded empty value.
  Future<void> remove(String key) => _watch(_prefs.remove(key), key);

  /// Re-reads the whole store from the platform, bypassing the plugin's
  /// in-memory cache. Used only by the debug round-trip check
  /// (`PhrasesController._debugVerifyRoundTrip`) — never on a production
  /// path.
  Future<void> reload() => _prefs.reload();

  Future<void> _watch(Future<bool> write, String key) async {
    try {
      await write;
    } catch (e, st) {
      // Key name only — the value could be child-specific content.
      unawaited(_telemetry.captureError(e, st,
          scope: 'storage/write', tags: {'storage_key': key}));
      rethrow;
    }
  }
}
