import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Renders the composed message as tactile word tiles (IMPLEMENTATION_PLAN
/// Task 4). POC edit affordance is **tap-to-remove (✕) only** (§2).
///
/// The in-progress word (keyboard mode, [activeIndex]) renders as the active
/// word with a caret — never a removable tile (§6.1.2).
class MessageBlocks extends StatefulWidget {
  const MessageBlocks({
    super.key,
    required this.tokens,
    required this.activeIndex,
    required this.placeholder,
    required this.onRemove,
  });

  final List<String> tokens;
  final int activeIndex;
  final String placeholder;
  final void Function(int index) onRemove;

  /// Locked line-height multiplier + size so every tile has a deterministic
  /// height, letting [MessageBar] size its visible area to whole rows.
  static const double tileTextHeight = 1.2;
  static const double tileFontSize = 30;

  /// Height of one word tile: text line box + vertical padding + border.
  static const double tileHeight =
      tileFontSize * tileTextHeight + AppTokens.s12 * 2 + 1.5 * 2;

  /// Vertical gap between wrapped rows of tiles.
  static const double rowSpacing = AppTokens.s8;

  /// Pixel height needed to show [rows] full rows of tiles.
  static double heightForRows(int rows) =>
      tileHeight * rows + rowSpacing * (rows - 1);

  @override
  State<MessageBlocks> createState() => _MessageBlocksState();
}

class _MessageBlocksState extends State<MessageBlocks> {
  int? _selected;

  @override
  void didUpdateWidget(MessageBlocks oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the selection valid as the message changes.
    if (_selected != null && _selected! >= widget.tokens.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.tokens.isEmpty) {
      return Text(
        widget.placeholder,
        style: TextStyle(
          color: colors.ink3,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Wrap(
      spacing: AppTokens.s8,
      runSpacing: MessageBlocks.rowSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < widget.tokens.length; i++)
          _tile(context, i, widget.tokens[i]),
      ],
    );
  }

  Widget _tile(BuildContext context, int i, String word) {
    final colors = context.colors;
    final isActive = i == widget.activeIndex;
    final isSelected = _selected == i && !isActive;

    return GestureDetector(
      onTap: isActive
          ? null
          : () => setState(() => _selected = isSelected ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.fromLTRB(
          AppTokens.s16,
          AppTokens.s12,
          isSelected ? AppTokens.s8 : AppTokens.s16,
          AppTokens.s12,
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.primarySoft : colors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colors.danger
                : isActive
                    ? colors.primary
                    : colors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word,
              style: TextStyle(
                color: colors.ink,
                fontSize: MessageBlocks.tileFontSize,
                height: MessageBlocks.tileTextHeight,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isActive)
              _Caret(color: colors.primary)
            else if (isSelected) ...[
              const SizedBox(width: AppTokens.s8),
              _RemoveButton(
                color: colors.danger,
                onTap: () {
                  setState(() => _selected = null);
                  widget.onRemove(i);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 30,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove word',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
