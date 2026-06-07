import '../core/app_language.dart';

enum KbRowType { number, accent, letters }

/// One keyboard row of character keys.
class KbRow {
  final List<String> keys;
  final KbRowType type;
  const KbRow(this.keys, [this.type = KbRowType.letters]);
}

/// Per-language layouts (IMPLEMENTATION_PLAN §6.2, ported from `LAYOUTS`).
/// English = QWERTY with a digit row. Czech = QWERTZ (y/z swapped) with a
/// 15-key diacritics row. Both render shift + backspace + space around them.
const Map<AppLanguage, List<KbRow>> kKeyboardLayouts = {
  AppLanguage.en: [
    KbRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'], KbRowType.number),
    KbRow(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']),
    KbRow(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l']),
    KbRow(['z', 'x', 'c', 'v', 'b', 'n', 'm']),
  ],
  AppLanguage.cs: [
    KbRow(['á', 'č', 'ď', 'é', 'ě', 'í', 'ň', 'ó', 'ř', 'š', 'ť', 'ú', 'ů', 'ý', 'ž'],
        KbRowType.accent),
    KbRow(['q', 'w', 'e', 'r', 't', 'z', 'u', 'i', 'o', 'p']),
    KbRow(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l']),
    KbRow(['y', 'x', 'c', 'v', 'b', 'n', 'm']),
  ],
};
