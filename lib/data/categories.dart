import 'package:flutter/material.dart';
import '../core/app_language.dart';

/// A symbol category. Labels are per-language; the hue is decorative
/// (each category owns a color, ported from the prototype's `CATEGORIES`,
/// with OKLCH approximated to sRGB).
class SymbolCategory {
  final String id;
  final String en;
  final String cs;
  final String uk;
  final String icon;
  final Color color;
  const SymbolCategory(this.id, this.en, this.cs, this.uk, this.icon, this.color);

  String label(AppLanguage l) => switch (l) {
        AppLanguage.en => en,
        AppLanguage.cs => cs,
        AppLanguage.uk => uk,
      };
}

const List<SymbolCategory> kCategories = [
  SymbolCategory('feelings', 'Feelings', 'Pocity', 'Почуття', '💛', Color(0xFFE8B53F)),
  SymbolCategory('food', 'Food', 'Jídlo', 'Їжа', '🍎', Color(0xFFE07A4E)),
  SymbolCategory('school', 'School', 'Škola', 'Школа', '✏️', Color(0xFF4F9BD1)),
  SymbolCategory('family', 'Family', 'Rodina', 'Родина', '👪', Color(0xFFB06BC9)),
  SymbolCategory('activities', 'Activities', 'Činnosti', 'Заняття', '⚽', Color(0xFF3DAE6B)),
  SymbolCategory('places', 'Places', 'Místa', 'Місця', '🏠', Color(0xFF6F8AD8)),
  SymbolCategory('numbers', 'Numbers', 'Čísla', 'Числа', '🔢', Color(0xFF3FA9A6)),
  SymbolCategory('greetings', 'Hello', 'Ahoj', 'Привіт', '👋', Color(0xFFD9A93C)),
];
