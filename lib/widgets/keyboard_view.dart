import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_language.dart';
import '../core/theme.dart';
import '../data/keyboard_layouts.dart';
import '../l10n/app_localizations.dart';
import '../state/composer_controller.dart';
import '../state/language_controller.dart';
import '../state/settings_controller.dart';

/// On-screen keyboard (IMPLEMENTATION_PLAN Task 5). Layout swaps with the
/// active language (EN QWERTY / CS QWERTZ-with-diacritics). Keys flex to fill
/// the row so the 15-key Czech accent row and 10-key letter rows both fit
/// without overflow (§6.1.3). No prediction row (cut, §3).
class KeyboardView extends StatefulWidget {
  const KeyboardView({super.key});

  @override
  State<KeyboardView> createState() => _KeyboardViewState();
}

class _KeyboardViewState extends State<KeyboardView> {
  bool _shift = false;

  void _haptic() {
    if (context.read<SettingsController>().haptics) {
      HapticFeedback.selectionClick();
    }
  }

  void _tapChar(String char) {
    _haptic();
    context.read<ComposerController>().addChar(char);
    if (_shift) setState(() => _shift = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageController>().language;
    final rows = kKeyboardLayouts[lang] ?? kKeyboardLayouts[AppLanguage.en]!;
    final lastLetterRow = rows.length - 1;

    return Column(
      children: [
        for (int ri = 0; ri < rows.length; ri++)
          Expanded(
            child: _CharRow(
              row: rows[ri],
              shift: _shift,
              withMods: ri == lastLetterRow,
              onShift: () => setState(() => _shift = !_shift),
              onBackspace: () {
                _haptic();
                context.read<ComposerController>().backspace();
              },
              onChar: _tapChar,
            ),
          ),
        Expanded(child: _SpaceRow(onChar: _tapChar)),
      ],
    );
  }
}

class _CharRow extends StatelessWidget {
  const _CharRow({
    required this.row,
    required this.shift,
    required this.withMods,
    required this.onShift,
    required this.onBackspace,
    required this.onChar,
  });

  final KbRow row;
  final bool shift;
  final bool withMods;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final void Function(String) onChar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
      child: Row(
        children: [
          if (withMods)
            _ModKey(
              flex: 14,
              active: shift,
              onTap: onShift,
              child: const Icon(Icons.arrow_upward_rounded, size: 24),
            ),
          for (final k in row.keys)
            _CharKey(
              label: shift && _hasCase(k) ? k.toUpperCase() : k,
              onTap: onChar,
            ),
          if (withMods)
            _ModKey(
              flex: 14,
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined, size: 24),
            ),
        ],
      ),
    );
  }

  bool _hasCase(String k) => k.toLowerCase() != k.toUpperCase();
}

class _CharKey extends StatelessWidget {
  const _CharKey({required this.label, required this.onTap});
  final String label;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      flex: 10,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: colors.keyBg,
          borderRadius: BorderRadius.circular(AppTokens.rKey),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.rKey),
            onTap: () => onTap(label),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.rKey),
                border: Border.all(color: colors.keyBorder, width: 1.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModKey extends StatelessWidget {
  const _ModKey({
    required this.flex,
    required this.onTap,
    required this.child,
    this.active = false,
  });

  final int flex;
  final VoidCallback onTap;
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: active ? colors.primarySoft : colors.keyMod,
          borderRadius: BorderRadius.circular(AppTokens.rKey),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.rKey),
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.rKey),
                border: Border.all(
                  color: active ? colors.primary : colors.keyBorder,
                  width: 1.5,
                ),
              ),
              child: IconTheme(
                data: IconThemeData(color: active ? colors.primary : colors.ink2),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({required this.onChar});
  final void Function(String) onChar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    Widget punct(String c) => _CharKey(label: c, onTap: onChar);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
      child: Row(
        children: [
          punct(','),
          Expanded(
            flex: 60,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Material(
                color: colors.keyBg,
                borderRadius: BorderRadius.circular(AppTokens.rKey),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.rKey),
                  onTap: () => onChar(' '),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.rKey),
                      border: Border.all(color: colors.keyBorder, width: 1.5),
                    ),
                    child: Text(
                      l10n.keySpace,
                      style: TextStyle(
                        color: colors.ink3,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          punct('.'),
          punct('!'),
          punct('?'),
        ],
      ),
    );
  }
}
