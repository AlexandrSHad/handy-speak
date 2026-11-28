import 'package:flutter/foundation.dart' show immutable;

/// A quick phrase belonging to one language (IMPLEMENTATION_PLAN §6).
///
/// The domain model *and* its JSON codec live here, below the controller
/// layer: `state/phrases_controller.dart` and the seed data depend on this
/// file, never the other way around (R1 architecture review, issue C1 —
/// this move breaks the former `data ⇄ state` import cycle).
///
/// Schema v2 (see `services/storage_keys.dart`): entries serialize as
/// `{id, text, pinned}`. The stable [id] (R1 review, M5) is assigned once —
/// by the seed data, by `PhrasesController.add`, or by the v1→v2 storage
/// migration — and never re-derived from position or text, so `remove` and
/// `togglePin` address exactly one phrase even when two share their text.
/// The never-incremented `uses` field was removed (M2, owner decision
/// 2026-11-28 — restore it only alongside a real usage counter).
///
/// `@immutable` still comes from `flutter/foundation.dart` — the model's
/// only framework need, kept from the pre-move file. Importing
/// `package:meta` instead would make this file pure Dart, but `meta` is
/// not a declared dependency (PR #13 review) and adding one widens what is
/// otherwise a pure move; revisit if the layer ever needs to be
/// framework-free.
@immutable
class Phrase {
  final int id;
  final String text;
  final bool pinned;
  const Phrase({required this.id, required this.text, this.pinned = false});

  Phrase copyWith({int? id, String? text, bool? pinned}) => Phrase(
        id: id ?? this.id,
        text: text ?? this.text,
        pinned: pinned ?? this.pinned,
      );

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'pinned': pinned};

  factory Phrase.fromJson(Map<String, dynamic> j) => Phrase(
        id: j['id'] as int,
        text: j['text'] as String,
        pinned: j['pinned'] as bool? ?? false,
      );
}
