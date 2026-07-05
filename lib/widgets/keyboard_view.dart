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
import 'forgiving_tap.dart';

/// On-screen keyboard (IMPLEMENTATION_PLAN Task 5). Layout swaps with the
/// active language (EN QWERTY / CS QWERTZ-with-diacritics). Keys flex to fill
/// the row so the 15-key Czech accent row and 10-key letter rows both fit
/// without overflow (§6.1.3). No prediction row (cut, §3).
///
/// ADDENDUM-02 (Czech inline numbers): Czech has no permanent digit row, so a
/// `123`/`ABC` toggle in the bottom row swaps the diacritics row in place for
/// `0–9` (teal-tinted to signal number mode). English already has a digit row
/// and gets no toggle.
class KeyboardView extends StatefulWidget {
  const KeyboardView({super.key});

  @override
  State<KeyboardView> createState() => _KeyboardViewState();
}

class _KeyboardViewState extends State<KeyboardView> {
  bool _shift = false;

  /// Czech-only inline-numbers toggle (ADDENDUM-02): swaps the diacritics row
  /// for `0–9` in place. Reset on every language change so a stale-open state
  /// never surprises on switching back to Czech.
  bool _numOpen = false;

  LanguageController? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.read<LanguageController>();
    if (_language != lang) {
      _language?.removeListener(_onLanguageChanged);
      _language = lang;
      _language!.addListener(_onLanguageChanged);
    }
  }

  @override
  void dispose() {
    _language?.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted && _numOpen) setState(() => _numOpen = false);
  }

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
    final hasNumRow = rows.any((r) => r.type == KbRowType.number);
    final lastLetterRow = rows.length - 1;
    final big = context.watch<SettingsController>().bigLetters;
    final colors = context.colors;
    // Big letters mode: shift is treated as OFF (and rendered inert) without
    // resetting the underlying _shift state (POC parity).
    final effShift = _shift && !big;

    return Column(
      children: [
        for (int ri = 0; ri < rows.length; ri++)
          Expanded(
            child: _CharRow(
              row: _resolveRow(rows[ri]),
              tintBg: _isSwapped(rows[ri]) ? colors.opSoft : null,
              tintInk: _isSwapped(rows[ri]) ? colors.opInk : null,
              big: big,
              effShift: effShift,
              withMods: ri == lastLetterRow,
              onShift: () => setState(() => _shift = !_shift),
              onBackspace: () {
                _haptic();
                context.read<ComposerController>().backspace();
              },
              onChar: _tapChar,
            ),
          ),
        Expanded(
          child: _SpaceRow(
            onChar: _tapChar,
            showNumToggle: !hasNumRow,
            numOpen: _numOpen,
            onToggleNum: () => setState(() => _numOpen = !_numOpen),
          ),
        ),
      ],
    );
  }

  /// True when [row] is the Czech diacritics row and the digit layer is open.
  bool _isSwapped(KbRow row) => row.type == KbRowType.accent && _numOpen;

  /// The row to actually render: the digit strip when swapped, else [row].
  KbRow _resolveRow(KbRow row) =>
      _isSwapped(row) ? const KbRow(_kDigits, KbRowType.number) : row;
}

/// Digits revealed by the Czech `123` toggle (POC `.num-strip`). 10 keys vs
/// the 15-key diacritics row — each `Expanded`, so they widen in place with
/// no motion or overlay.
const _kDigits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

class _CharRow extends StatelessWidget {
  const _CharRow({
    required this.row,
    required this.big,
    required this.effShift,
    required this.withMods,
    required this.onShift,
    required this.onBackspace,
    required this.onChar,
    this.tintBg,
    this.tintInk,
  });

  final KbRow row;
  final bool big;
  final bool effShift;
  final bool withMods;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final void Function(String) onChar;

  /// Optional teal tint for the swapped Czech digit row (ADDENDUM-02). Null
  /// for every other row → default key colors.
  final Color? tintBg;
  final Color? tintInk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
      child: Row(
        children: [
          if (withMods)
            _ModKey(
              flex: 14,
              active: effShift,
              enabled: !big,
              onTap: onShift,
              child: const Icon(Icons.arrow_upward_rounded, size: 24),
            ),
          for (final k in row.keys)
            _CharKey(
              // Display-only uppercasing; the inserted value keeps stored
              // casing (lowercase unless shift is genuinely active).
              label: (big || (effShift && _hasCase(k))) ? k.toUpperCase() : k,
              value: effShift && _hasCase(k) ? k.toUpperCase() : k,
              onTap: onChar,
              tintBg: tintBg,
              tintInk: tintInk,
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
  const _CharKey({
    required this.label,
    required this.value,
    required this.onTap,
    this.tintBg,
    this.tintInk,
  });

  /// What the child sees on the keycap (may be display-uppercased).
  final String label;

  /// What actually gets inserted — always the stored casing.
  final String value;
  final void Function(String) onTap;

  /// Optional tint (swapped Czech digit row only). Null → default colors.
  final Color? tintBg;
  final Color? tintInk;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = tintBg ?? colors.keyBg;
    final fg = tintInk ?? colors.ink;
    return Expanded(
      flex: 10,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.rKey),
          child: ForgivingTap(
            borderRadius: BorderRadius.circular(AppTokens.rKey),
            onTap: () => onTap(value),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.rKey),
                border: Border.all(color: colors.keyBorder, width: 1.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
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
    this.enabled = true,
  });

  final int flex;
  final VoidCallback onTap;
  final Widget child;
  final bool active;

  /// When false the key is rendered inert: dimmed, no tap/ripple/hover,
  /// and never shown as active.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isActive = active && enabled;
    Widget key = Material(
      color: isActive ? colors.primarySoft : colors.keyMod,
      borderRadius: BorderRadius.circular(AppTokens.rKey),
      child: ForgivingTap(
        borderRadius: BorderRadius.circular(AppTokens.rKey),
        // Null passthrough keeps the inert-shift contract: the inner
        // InkWell.onTap stays null, which ADDENDUM-01 tests assert.
        onTap: enabled ? onTap : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rKey),
            border: Border.all(
              color: isActive ? colors.primary : colors.keyBorder,
              width: 1.5,
            ),
          ),
          child: IconTheme(
            data: IconThemeData(color: isActive ? colors.primary : colors.ink2),
            child: child,
          ),
        ),
      ),
    );
    if (!enabled) key = Opacity(opacity: 0.35, child: key);
    return Expanded(
      flex: flex,
      child: Padding(padding: const EdgeInsets.all(3), child: key),
    );
  }
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.onChar,
    this.showNumToggle = false,
    this.numOpen = false,
    this.onToggleNum,
  });

  final void Function(String) onChar;

  /// Show the `123`/`ABC` toggle (only when the layout has no digit row,
  /// i.e. Czech — ADDENDUM-02).
  final bool showNumToggle;

  /// Whether the inline digit layer is open (drives the `123`/`ABC` label).
  final bool numOpen;

  final VoidCallback? onToggleNum;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    Widget punct(String c) => _CharKey(label: c, value: c, onTap: onChar);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
      child: Row(
        children: [
          if (showNumToggle)
            _NumToggleKey(active: numOpen, onTap: onToggleNum!),
          punct(','),
          Expanded(
            flex: 60,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Material(
                color: colors.keyBg,
                borderRadius: BorderRadius.circular(AppTokens.rKey),
                child: ForgivingTap(
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

/// `123`/`ABC` toggle that swaps the Czech diacritics row for digits
/// (ADDENDUM-02). Styled like `_ModKey` (`keyMod` bg, pressed state when
/// open). Labels are literal glyphs — never localized.
class _NumToggleKey extends StatelessWidget {
  const _NumToggleKey({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      flex: 14,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: active ? colors.primarySoft : colors.keyMod,
          borderRadius: BorderRadius.circular(AppTokens.rKey),
          child: ForgivingTap(
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
              child: Text(
                active ? 'ABC' : '123',
                style: TextStyle(
                  color: active ? colors.primary : colors.ink2,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
