import 'package:flutter/foundation.dart' show immutable;

/// A quick phrase belonging to one language (IMPLEMENTATION_PLAN §6).
///
/// The domain model *and* its JSON codec live here, below the controller
/// layer: `state/phrases_controller.dart` and the seed data depend on this
/// file, never the other way around (R1 architecture review, issue C1 —
/// this move breaks the former `data ⇄ state` import cycle).
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
