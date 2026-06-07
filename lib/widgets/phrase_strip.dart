import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../state/composer_controller.dart';
import '../state/language_controller.dart';
import '../state/phrases_controller.dart';
import '../state/settings_controller.dart';

/// My Phrases: pinned-first quick phrases for the active language
/// (IMPLEMENTATION_PLAN Task 7). Tapping one loads it into the message bar.
class PhraseStrip extends StatelessWidget {
  const PhraseStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final lang = context.watch<LanguageController>().language;
    final phrases = context.watch<PhrasesController>().phrasesFor(lang);

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.s12),
            child: Row(
              children: [
                const Text('📌', style: TextStyle(fontSize: 16)),
                const SizedBox(width: AppTokens.s8),
                Text(
                  l10n.myPhrases.toUpperCase(),
                  style: TextStyle(
                    color: colors.ink3,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: phrases.length > 8 ? 8 : phrases.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppTokens.s8),
              itemBuilder: (context, i) {
                final p = phrases[i];
                return Center(
                  child: _Chip(
                    label: p.text,
                    pinned: p.pinned,
                    onTap: () {
                      if (context.read<SettingsController>().haptics) {
                        HapticFeedback.selectionClick();
                      }
                      context.read<ComposerController>().loadText(p.text);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.pinned, required this.onTap});

  final String label;
  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: pinned ? colors.primarySoft : colors.surface2,
      borderRadius: BorderRadius.circular(AppTokens.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.rPill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s16,
            vertical: AppTokens.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rPill),
            border: Border.all(
              color: pinned ? colors.primary : colors.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pinned) ...[
                Icon(Icons.push_pin, size: 14, color: colors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
