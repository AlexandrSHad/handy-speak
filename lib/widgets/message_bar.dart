import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../state/composer_controller.dart';
import 'message_blocks.dart';
import 'speak_button.dart';

/// The editable message card + word count + Clear, with the Speak button
/// beside it (IMPLEMENTATION_PLAN Task 4). No mood voice-chip is shown
/// (moods off, §2).
///
/// The tile area grows to fit up to two rows of word tiles without scrolling.
/// A third row makes it scroll, auto-scrolling so the newest (bottom) row
/// stays visible as the message grows.
class MessageBar extends StatefulWidget {
  const MessageBar({super.key});

  @override
  State<MessageBar> createState() => _MessageBarState();
}

class _MessageBarState extends State<MessageBar> {
  /// Rows of tiles shown before the area starts scrolling.
  static const int _visibleRows = 2;

  final ScrollController _scroll = ScrollController();
  String _prevText = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keep the newest (bottom) row visible after the next layout.
  void _keepBottomVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final composer = context.watch<ComposerController>();

    // Scroll to the newest row whenever the message grows (new word/char).
    if (composer.text.length > _prevText.length) _keepBottomVisible();
    _prevText = composer.text;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s24,
              vertical: AppTokens.s16,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppTokens.rMessage),
              border: Border.all(color: colors.dividerSoft, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grows with content up to [_visibleRows]; scrolls beyond.
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MessageBlocks.heightForRows(1),
                      maxHeight: MessageBlocks.heightForRows(_visibleRows),
                    ),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: MessageBlocks(
                        tokens: composer.tokens,
                        activeIndex: composer.activeIndex,
                        placeholder: l10n.composePlaceholder,
                        onRemove: composer.removeWordAt,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.s8),
                Row(
                  children: [
                    Text(
                      l10n.wordCount(composer.wordCount),
                      style: TextStyle(
                        color: colors.ink3,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (composer.text.isNotEmpty)
                      TextButton(
                        onPressed: composer.clear,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.ink2,
                        ),
                        child: Text(
                          l10n.clear,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTokens.s16),
        const SpeakButton(),
      ],
    );
  }
}
