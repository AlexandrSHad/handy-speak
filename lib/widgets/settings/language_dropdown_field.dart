import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';

/// A language-set slot dropdown (ADDENDUM-04) in the app-wide card-input
/// idiom — the theme's `InputDecorationTheme` supplies fill, radius and
/// borders; this widget owns the dropdown-specific anatomy.
///
/// Invariants to copy for any future dropdown:
/// - **Never pin the field to a fixed height, never pad the closed row.**
///   The closed state is a BARE text line (badge sized inside the line
///   box), so the field sizes from the same decorator metrics + text-line
///   driver as every other input and grows with system text scale.
///   Accessibility font scaling is common on this app's tablets; a fixed
///   height makes the field look shrunken next to inputs that scale.
///   Pinned by the addendum04 height tests (dropdown == phrase input at
///   text scales 1.0 and 1.3).
/// - The vertical contentPadding (16) pairs the dropdown's smaller
///   intrinsic button with the theme-default TextField metrics so both
///   land on equal heights. If input metrics ever change, re-run those
///   tests.
/// - Menu items keep a 52 px minimum (AAC tap target); the menu rounds to
///   the field radius; items render the short-code chip + endonym, never
///   flags (design rule).
/// - Test keys: `settingsLangDropdown_{slot}` on the field,
///   `settingsLangItem_{slot}_{lang}` per menu item.
class LanguageDropdownField extends StatelessWidget {
  const LanguageDropdownField({
    super.key,
    required this.slot,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String slot;
  final AppLanguage value;
  final List<AppLanguage> items;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget chip(AppLanguage l) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.divider),
          ),
          child: Text(l.short,
              style: TextStyle(
                  color: colors.ink2,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        );
    Widget slotLabel(AppLanguage l) => Row(
          children: [
            chip(l),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Text(
                l.nativeName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

    return DropdownButtonFormField<AppLanguage>(
      key: ValueKey('settingsLangDropdown_$slot'),
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(AppTokens.rInput),
      icon: Icon(Icons.arrow_drop_down, color: colors.ink3),
      // Closed state renders its own bare text line — NOT the 52 px menu
      // item, which the decorator's padding would clip (see class docs).
      selectedItemBuilder: (_) => [
        for (final l in items)
          Container(
            alignment: Alignment.centerLeft,
            child: slotLabel(l),
          ),
      ],
      items: [
        for (final l in items)
          DropdownMenuItem(
            value: l,
            child: Container(
              key: ValueKey('settingsLangItem_${slot}_${l.name}'),
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.centerLeft,
              child: slotLabel(l),
            ),
          ),
      ],
      onChanged: (l) {
        if (l != null) onChanged(l);
      },
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppTokens.s16, vertical: 16),
      ),
    );
  }
}
