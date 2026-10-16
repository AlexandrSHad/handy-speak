import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/app_language.dart';
import '../data/phrases_data.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';

/// A quick phrase belonging to one language (IMPLEMENTATION_PLAN §6).
@immutable
class Phrase {
  final String text;
  final bool pinned;
  final int uses;
  const Phrase({required this.text, this.pinned = false, this.uses = 0});

  Phrase copyWith({String? text, bool? pinned, int? uses}) => Phrase(
        text: text ?? this.text,
        pinned: pinned ?? this.pinned,
        uses: uses ?? this.uses,
      );

  Map<String, dynamic> toJson() =>
      {'text': text, 'pinned': pinned, 'uses': uses};

  factory Phrase.fromJson(Map<String, dynamic> j) => Phrase(
        text: j['text'] as String,
        pinned: j['pinned'] as bool? ?? false,
        uses: j['uses'] as int? ?? 0,
      );
}

/// Per-language phrase lists, seeded and persisted independently
/// (IMPLEMENTATION_PLAN §6.1.4 / Task 7). Stored under `phrases_en` /
/// `phrases_cs` as JSON.
class PhrasesController extends ChangeNotifier {
  PhrasesController(this._storage, {TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService();

  final StorageService _storage;
  final TelemetryService _telemetry;
  final Map<AppLanguage, List<Phrase>> _byLang = {};

  static String _key(AppLanguage l) => 'phrases_${l.key}';

  void load() {
    for (final lang in AppLanguage.values) {
      final raw = _storage.getString(_key(lang));
      if (raw == null) {
        _byLang[lang] = List.of(kSeedPhrases[lang] ?? const []);
      } else {
        try {
          final list = (jsonDecode(raw) as List)
              .map((e) => Phrase.fromJson(e as Map<String, dynamic>))
              .toList();
          _byLang[lang] = list;
        } catch (e, st) {
          _byLang[lang] = List.of(kSeedPhrases[lang] ?? const []);
          // Silent data loss of a parent's saved phrases — report it
          // (ADDENDUM-06). The exception message echoes the stored JSON (i.e.
          // phrase text), so the scope policy suppresses it: type + tags
          // only, `raw_length` is a number, never content (ADR-0004).
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

  /// Phrases for [lang], pinned-first then by use count (Task 7).
  List<Phrase> phrasesFor(AppLanguage lang) {
    final list = List<Phrase>.of(_byLang[lang] ?? const []);
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.uses.compareTo(a.uses);
    });
    return list;
  }

  void add(AppLanguage lang, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _byLang.putIfAbsent(lang, () => []);
    _byLang[lang]!.add(Phrase(text: trimmed, pinned: true));
    _persist(lang);
    notifyListeners();
  }

  void remove(AppLanguage lang, Phrase phrase) {
    _byLang[lang]?.removeWhere((p) => identical(p, phrase) || p.text == phrase.text);
    _persist(lang);
    notifyListeners();
  }

  void togglePin(AppLanguage lang, Phrase phrase) {
    final list = _byLang[lang];
    if (list == null) return;
    final i = list.indexWhere((p) => p.text == phrase.text);
    if (i < 0) return;
    list[i] = list[i].copyWith(pinned: !list[i].pinned);
    _persist(lang);
    notifyListeners();
  }

  void _persist(AppLanguage lang) {
    final raw = jsonEncode(_byLang[lang]!.map((p) => p.toJson()).toList());
    _storage.setString(_key(lang), raw);
  }
}
