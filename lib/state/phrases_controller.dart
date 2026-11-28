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

  /// True while the most recent persist FAILED (S02-issue-C3 item 3 — the
  /// save-failure channel). Set in [_persist]'s failure path, cleared by
  /// the next successful persist; notifies on both transitions so the
  /// Phrases pane can show/hide its [NoticeBanner]. Transient by design:
  /// it says "the last save attempt did not land", never "the list is
  /// broken" — the in-memory list keeps every edit, and the next
  /// successful persist rewrites the whole blob.
  bool _saveFailed = false;
  bool get saveFailed => _saveFailed;

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
          // Backup BEFORE the destructive fallback: quarantine the corrupt
          // blob under `phrases_<lang>.corrupt` (one setString,
          // self-capping — the slot is overwritten, never appended to),
          // then drop the original key so the re-seeded list is what the
          // next boot restores. The parent's content stays on-device for a
          // support path to recover (S02-issue-C3 item 4).
          unawaited(_storage.setString(phrasesCorruptKey(lang), raw));
          unawaited(_storage.remove(phrasesKey(lang)));
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

  /// Enqueues one [_persist] onto the serialized pipeline. [_persist] never
  /// throws (it owns the save-failure state), so a failed write cannot
  /// wedge the queue.
  void _schedulePersist(AppLanguage lang) {
    _persistQueue = (_persistQueue ?? Future<void>.value())
        .then((_) => _persist(lang));
  }

  Future<void> _persist(AppLanguage lang) async {
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
