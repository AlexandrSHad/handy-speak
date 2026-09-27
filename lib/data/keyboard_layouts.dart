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
/// 15-key diacritics row. ů/ú lead the row (order requested by the child's
/// logoped — on the physical Czech ČSN QWERTZ keyboard they sit on
/// different rows, so the single-row order is our own choice); ě š č ř ž
/// ý á í é follow the ČSN number-row order left→right; then the
/// dead-key-composed ď ť ň, with ó last (composed ´+o; no key of its own). All render shift + backspace + space
/// around them.
const Map<AppLanguage, List<KbRow>> kKeyboardLayouts = {
  AppLanguage.en: [
    KbRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'], KbRowType.number),
    KbRow(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']),
    KbRow(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l']),
    KbRow(['z', 'x', 'c', 'v', 'b', 'n', 'm']),
  ],
  AppLanguage.cs: [
    KbRow(['ů', 'ú', 'ě', 'š', 'č', 'ř', 'ž', 'ý', 'á', 'í', 'é', 'ď', 'ť', 'ň', 'ó'],
        KbRowType.accent),
    KbRow(['q', 'w', 'e', 'r', 't', 'z', 'u', 'i', 'o', 'p']),
    KbRow(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l']),
    KbRow(['y', 'x', 'c', 'v', 'b', 'n', 'm']),
  ],
  AppLanguage.uk: [
    KbRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'], KbRowType.number),
    KbRow(['й', 'ц', 'у', 'к', 'е', 'н', 'г', 'ш', 'щ', 'з', 'х', 'ї']),
    KbRow(['ф', 'і', 'в', 'а', 'п', 'р', 'о', 'л', 'д', 'ж', 'є', 'ґ']),
    KbRow(['я', 'ч', 'с', 'м', 'и', 'т', 'ь', 'б', 'ю', 'ʼ']),
  ],
};
