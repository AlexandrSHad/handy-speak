import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/text_display.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../state/composer_controller.dart';
import '../state/settings_controller.dart';
import 'forgiving_tap.dart';

/// Math board (ADDENDUM-02): a third input "voice" that composes a problem
/// the same way every other board composes a message — Speak reads the whole
/// problem in words. It is **never a calculator**: no evaluation, no result,
/// `=` is a plain peer key.
///
/// One aligned 4×5 grid; consecutive digits group into one message tile
/// (handled in [ComposerController]/`math_speak.dart`), each operator and
/// comparison is its own tile. The trailing in-progress number renders with
/// the caret in the shared message bar (not removable while typing);
/// completed tiles are removable — the bar already does that from
/// `composer.tokens`/`activeIndex`, so this board owns no tile state.
class MathBoard extends StatelessWidget {
  const MathBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _kRows) Expanded(child: _MathRow(keys: row)),
      ],
    );
  }
}

/// What a key is — picks the tint and how the tap routes.
enum _Kind { digit, op, rel, backspace }

class _Def {
  const _Def(this.label, this.kind, {this.flex = 1});
  final String label;
  final _Kind kind;
  final int flex;
}

// Calculator order. `−` is the true minus U+2212 (never ASCII `-`); it must be
// identical here, in the stored token, in the MATH_SPEAK map, and in any
// backspace test — a stray ASCII '-' silently breaks the spoken-word lookup.
// `.` is a `_Kind.digit` so it joins the trailing number (one tile: "3.5").
const _kRows = <List<_Def>>[
  [_Def('7', _Kind.digit), _Def('8', _Kind.digit), _Def('9', _Kind.digit), _Def('÷', _Kind.op)],
  [_Def('4', _Kind.digit), _Def('5', _Kind.digit), _Def('6', _Kind.digit), _Def('×', _Kind.op)],
  [_Def('1', _Kind.digit), _Def('2', _Kind.digit), _Def('3', _Kind.digit), _Def('−', _Kind.op)],
  [_Def('0', _Kind.digit, flex: 2), _Def('.', _Kind.digit), _Def('+', _Kind.op)],
  [_Def('<', _Kind.rel), _Def('>', _Kind.rel), _Def('=', _Kind.rel), _Def('⌫', _Kind.backspace)],
];

class _MathRow extends StatelessWidget {
  const _MathRow({required this.keys});
  final List<_Def> keys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
      child: Row(
        children: [for (final k in keys) _MathKey(def: k)],
      ),
    );
  }
}

class _MathKey extends StatelessWidget {
  const _MathKey({required this.def});
  final _Def def;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final big = context.select<SettingsController, bool>((s) => s.bigLetters);

    final (Color bg, Color fg) = switch (def.kind) {
      _Kind.digit => (colors.keyBg, colors.ink),
      _Kind.op => (colors.opSoft, colors.opInk),
      _Kind.rel => (colors.relSoft, colors.relInk),
      _Kind.backspace => (colors.keyMod, colors.ink2),
    };

    return Expanded(
      flex: def.flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          button: true,
          label: def.kind == _Kind.backspace ? l10n.keyBackspace : def.label,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(AppTokens.rKey),
            child: ForgivingTap(
              borderRadius: BorderRadius.circular(AppTokens.rKey),
              onTap: () {
                final composer = context.read<ComposerController>();
                if (context.read<SettingsController>().haptics) {
                  HapticFeedback.selectionClick();
                }
                switch (def.kind) {
                  case _Kind.digit:
                    composer.appendMathDigit(def.label); // '.' joins the number
                  case _Kind.op:
                  case _Kind.rel:
                    composer.appendMathOp(def.label);
                  case _Kind.backspace:
                    composer.mathBackspace();
                }
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.rKey),
                  border: Border.all(color: colors.keyBorder, width: 1.5),
                ),
                child: def.kind == _Kind.backspace
                    ? Icon(Icons.backspace_outlined, size: 26, color: fg)
                    : Text(
                        def.label.displayUpper(big),
                        style: TextStyle(
                          color: fg,
                          fontSize: switch (def.kind) {
                            _Kind.op => 36,
                            _Kind.digit => 34,
                            _Kind.rel => 32,
                            _Kind.backspace => 24, // unused (icon path)
                          },
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
