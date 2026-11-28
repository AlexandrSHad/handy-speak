import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/app_language.dart';
import '../data/phrase.dart';
import '../data/phrases_data.dart';
import '../services/storage_keys.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';

// `Phrase` moved to `data/phrase.dart` (R1 C1). Re-exported here so every
// existing consumer that reads `Phrase` through this controller keeps
// compiling unchanged; new consumers import `data/phrase.dart` directly and
// stay decoupled from the controller.
export '../data/phrase.dart';

/// Per-language phrase lists, seeded and persisted independently
/// (IMPLEMENTATION_PLAN §6.1.4 / Task 7). Stored under `phrases_en` /
/// `phrases_cs` / `phrases_uk` as v2-schema JSON — see
/// `services/storage_keys.dart` for the schema and its migration.
class PhrasesController extends ChangeNotifier {
  PhrasesController(this._storage, {TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService();

  final StorageService _storage;
  final TelemetryService _telemetry;
  final Map<AppLanguage, List<Phrase>> _byLang = {};

  /// The serialized persist pipeline: each blob write (and its debug
  /// round-trip check) completes before the next starts, so two rapid
  /// mutations cannot interleave their writes or their checks — each
  /// snapshot the store holds is always the newest one, in order.
  Future<void>? _persistQueue;

  /// True while phrase saves are not landing — the Phrases pane's
  /// save-failure banner state (S02-issue-C3 item 3). Two sources:
  ///
  /// * [_saveFailed] — the most recent persist FAILED: transient, set in
  ///   [_persist]'s failure path, cleared by the next successful persist,
  ///   notifies on transitions.
  /// * [_quarantineFailed] — a corrupt blob's backup failed at load: lasts
  ///   the session (the next boot retries the backup), and persists for
  ///   that language are blocked (see [_quarantine]).
  ///
  /// Neither ever means "the list is broken" — the in-memory list keeps
  /// every edit, and the next successful persist rewrites the whole blob
  /// (unless a quarantine is outstanding, when the only resolution is a
  /// restart, which retries the backup).
  bool get saveFailed => _saveFailed || _quarantineFailed.isNotEmpty;
  bool _saveFailed = false;

  /// Languages whose corrupt blob could NOT be backed up: the original key
  /// is still the only surviving copy, so [_persist] refuses to write those
  /// lists — a re-seeded in-memory state must never overwrite the last copy
  /// of the parent's content. Cleared only by the next boot, which re-runs
  /// the backup (round-1 review, PR #15 finding 1).
  final Set<AppLanguage> _quarantineFailed = {};

  void load() {
    for (final lang in AppLanguage.values) {
      final raw = _storage.getString(phrasesKey(lang));
      if (raw == null) {
        _byLang[lang] = List.of(kSeedPhrases[lang] ?? const []);
      } else {
        try {
          final list = (jsonDecode(raw) as List)
              .map((e) => Phrase.fromJson(e as Map<String, dynamic>))
              .toList();
          _byLang[lang] = list;
        } catch (e, st) {
          // Quarantine the corrupt blob BEFORE the destructive fallback
          // (S02-issue-C3 item 4): copy it under `phrases_<lang>.corrupt`
          // (self-capping — the single slot is overwritten, never appended
          // to), then — only once the backup has landed — drop the
          // original key, so the re-seeded list is what the next boot
          // restores and the parent's content stays on-device for a
          // support path to recover. The remove is chained strictly after
          // a successful backup; on a failed backup the original key stays
          // in place and persists for the language are blocked (see
          // [_quarantine]) — the next boot re-reports and retries, which
          // is the safe direction (PR #15 round-1 finding 1).
          unawaited(_quarantine(lang, raw));
          _byLang[lang] = List.of(kSeedPhrases[lang] ?? const []);
          // Silent data loss of a parent's saved phrases — report it
          // (ADDENDUM-06). The exception message echoes the stored JSON
          // (i.e. phrase text), so the scope policy suppresses it: type +
          // tags only, `raw_length` is a number, never content (ADR-0004).
          unawaited(_telemetry.captureError(e, st,
              scope: 'phrases/load_corrupt',
              tags: {
                'phrases_lang': lang.key,
                'raw_length': raw.length.toString(),
              }));
        }
      }
    }
  }

  /// Phrases for [lang], pinned first and otherwise in insertion order.
  /// (Task 7's original uses-descending sort was removed with the `uses`
  /// field — M2, owner decision 2026-11-28: the counter was never
  /// incremented, so the "most used" order was frozen seed data and
  /// parent-added phrases always sank to the bottom.)
  List<Phrase> phrasesFor(AppLanguage lang) {
    final list = _byLang[lang] ?? const [];
    return [
      ...list.where((p) => p.pinned),
      ...list.where((p) => !p.pinned),
    ];
  }

  void add(AppLanguage lang, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final list = _byLang.putIfAbsent(lang, () => []);
    // M5: one-up the highest id in the list, so two same-text phrases stay
    // distinct and removal/pinning always addresses exactly one row.
    var maxId = -1;
    for (final p in list) {
      if (p.id > maxId) maxId = p.id;
    }
    list.add(Phrase(id: maxId + 1, text: trimmed, pinned: true));
    _schedulePersist(lang);
    notifyListeners();
  }

  void remove(AppLanguage lang, Phrase phrase) {
    _byLang[lang]?.removeWhere((p) => p.id == phrase.id);
    _schedulePersist(lang);
    notifyListeners();
  }

  void togglePin(AppLanguage lang, Phrase phrase) {
    final list = _byLang[lang];
    if (list == null) return;
    final i = list.indexWhere((p) => p.id == phrase.id);
    if (i < 0) return;
    list[i] = list[i].copyWith(pinned: !list[i].pinned);
    _schedulePersist(lang);
    notifyListeners();
  }

  /// Quarantines a corrupt blob (from [load]'s failure path).
  ///
  /// The remove of the original key is chained strictly AFTER the backup
  /// write succeeds: `shared_preferences` has no multi-key transaction,
  /// and two independent fire-and-forget writes could drop the original
  /// key while the backup never landed — the unrecoverable loss this
  /// whole issue exists to remove (PR #15 round-1 finding 1; the plugin
  /// mutates its Dart-side cache synchronously *before* the platform
  /// call, so a rejected `setString` leaves the cache looking written
  /// while the disk never saw it — only the disk survives a reboot).
  ///
  /// On a failed backup: the original key stays exactly where it is,
  /// [lang] joins [_quarantineFailed] (which turns [saveFailed] on and
  /// makes [_persist] refuse to write the language — a re-seeded
  /// in-memory list must never overwrite the last surviving copy), and
  /// the next boot re-runs this whole path and retries. On a successful
  /// backup: remove the original; if that remove itself fails, no state
  /// is needed — the copy exists, so the next mutation's persist may
  /// overwrite the original, and the next boot re-runs idempotently.
  Future<void> _quarantine(AppLanguage lang, String raw) async {
    try {
      await _storage.setString(phrasesCorruptKey(lang), raw);
    } catch (_) {
      // The write seam already captured the failure (`storage/write`,
      // key-only tags); nothing to re-report here.
      _quarantineFailed.add(lang);
      notifyListeners();
      return;
    }
    try {
      await _storage.remove(phrasesKey(lang));
    } catch (_) {
      // Backup landed — the original surviving one more boot is harmless;
      // the seam captured this write failure too.
    }
  }

  /// Enqueues one [_persist] onto the serialized pipeline. [_persist] never
  /// throws (it owns the save-failure state), so a failed write cannot
  /// wedge the queue.
  void _schedulePersist(AppLanguage lang) {
    _persistQueue = (_persistQueue ?? Future<void>.value())
        .then((_) => _persist(lang));
  }

  Future<void> _persist(AppLanguage lang) async {
    if (_quarantineFailed.contains(lang)) {
      // The re-seeded list is NOT the parent's stored content — writing it
      // would overwrite the only surviving copy of a corrupt blob whose
      // backup failed (see [_quarantine]). Edits stay in memory, the
      // banner (via [saveFailed]) stays up, and the next boot retries the
      // backup. Deliberately NOT a `_saveFailed` transition: nothing was
      // written, so there is no write outcome to report.
      return;
    }
    final key = phrasesKey(lang);
    final raw = jsonEncode(_byLang[lang]!.map((p) => p.toJson()).toList());
    try {
      await _storage.setString(key, raw);
      if (_saveFailed) {
        _saveFailed = false;
        notifyListeners();
      }
      await _debugVerifyRoundTrip(key, raw);
    } catch (_) {
      // The storage seam already captured the failure (`storage/write`,
      // key-only tags). All that is left is the in-app signal.
      if (!_saveFailed) {
        _saveFailed = true;
        notifyListeners();
      }
    }
  }

  /// S02-issue-C3 item 5 (optional, implemented): debug-only round-trip
  /// verification of the critical write. Reloads the store from the
  /// platform — bypassing the plugin's in-memory cache, which a
  /// successful-looking call that never reached disk would leave healthy —
  /// and compares what comes back with what was written. A mismatch
  /// debugPrints (lengths only, never content); it never throws and never
  /// touches the banner state.
  Future<void> _debugVerifyRoundTrip(String key, String raw) async {
    if (!kDebugMode) return;
    try {
      await _storage.reload();
      final readBack = _storage.getString(key);
      if (readBack != raw) {
        debugPrint('phrases: round-trip mismatch on $key — stored '
            '${readBack?.length ?? 0}B, wrote ${raw.length}B');
      }
    } catch (e) {
      debugPrint('phrases: round-trip check failed: $e');
    }
  }
}
