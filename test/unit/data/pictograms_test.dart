import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/data/pictograms.dart';
import 'package:handy_speak/data/symbol_categories.dart';

// Static-data invariants spanning the two symbol sources: `kSymbolCategories`
// (the category list) and `kPictograms` (pictograms keyed by category id). The
// load-bearing check is the cross-reference BETWEEN them — every category owns
// pictograms and no pictogram bucket dangles without a category. Pure data
// assertions: no widget tree, no binding.

void main() {
  group('kSymbolCategories · shape', () {
    test('category ids are unique', () {
      final ids = kSymbolCategories.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every category has non-empty labels in EN, CS and UK', () {
      for (final cat in kSymbolCategories) {
        for (final lang in AppLanguage.values) {
          expect(cat.label(lang).trim(), isNotEmpty,
              reason: 'category "${cat.id}" has a blank ${lang.name} label');
        }
      }
    });

    test('every category has a non-empty icon glyph', () {
      for (final cat in kSymbolCategories) {
        expect(cat.icon.trim(), isNotEmpty, reason: 'category "${cat.id}"');
      }
    });
  });

  group('kPictograms · per-pictogram invariants', () {
    test('every category bucket has at least one pictogram', () {
      for (final entry in kPictograms.entries) {
        expect(entry.value, isNotEmpty,
            reason: 'bucket "${entry.key}" is empty');
      }
    });

    test('every pictogram has a non-empty word in EN, CS and UK', () {
      for (final entry in kPictograms.entries) {
        for (final picto in entry.value) {
          for (final lang in AppLanguage.values) {
            expect(picto.word(lang).trim(), isNotEmpty,
                reason: 'pictogram "${picto.emoji}" in "${entry.key}" '
                    'has a blank ${lang.name} word');
          }
        }
      }
    });

    test('every pictogram carries a non-empty emoji glyph', () {
      for (final entry in kPictograms.entries) {
        for (final picto in entry.value) {
          expect(picto.emoji.trim(), isNotEmpty,
              reason: 'a pictogram in "${entry.key}" has no emoji');
        }
      }
    });
  });

  group('category ↔ pictogram cross-reference', () {
    test('every category id has a pictogram bucket', () {
      for (final cat in kSymbolCategories) {
        expect(kPictograms.containsKey(cat.id), isTrue,
            reason: 'category "${cat.id}" has no pictograms');
      }
    });

    test('no pictogram bucket dangles without a category', () {
      final categoryIds = kSymbolCategories.map((c) => c.id).toSet();
      for (final key in kPictograms.keys) {
        expect(categoryIds, contains(key),
            reason: 'pictogram bucket "$key" references a missing category');
      }
    });

    test('the two id sets are exactly equal (complete & consistent)', () {
      final categoryIds = kSymbolCategories.map((c) => c.id).toSet();
      expect(kPictograms.keys.toSet(), categoryIds);
    });
  });
}
