import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_language.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../state/composer_controller.dart';
import '../state/language_controller.dart';
import '../state/settings_controller.dart';

/// Brand, Keyboard/Symbols toggle, EN/CZ language toggle and a settings button
/// (IMPLEMENTATION_PLAN Task 3).
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _Brand(),
        const Spacer(),
        const _ModeToggle(),
        const Spacer(),
        const _LanguageToggle(),
        const SizedBox(width: AppTokens.s12),
        Material(
          color: colors.surface,
          shape: CircleBorder(side: BorderSide(color: colors.divider)),
          child: IconButton(
            tooltip: l10n.settings,
            onPressed: onOpenSettings,
            icon: Icon(Icons.settings_outlined, color: colors.ink2),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.primary, colors.accent]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.graphic_eq, color: Colors.white, size: 22),
        ),
        const SizedBox(width: AppTokens.s12),
        Text(
          AppLocalizations.of(context)!.appTitle,
          style: TextStyle(
            color: colors.ink,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final mode = context.select<ComposerController, InputMode>((c) => c.mode);

    Widget seg(InputMode m, IconData icon, String label) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => context.read<ComposerController>().setMode(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s16,
            vertical: AppTokens.s12,
          ),
          decoration: BoxDecoration(
            color: active ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: active ? colors.ink : colors.ink3),
              const SizedBox(width: AppTokens.s8),
              Text(
                label,
                style: TextStyle(
                  color: active ? colors.ink : colors.ink3,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          seg(InputMode.keyboard, Icons.keyboard_outlined, l10n.modeKeyboard),
          seg(InputMode.symbols, Icons.grid_view_rounded, l10n.modeSymbols),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = context.select<LanguageController, AppLanguage>((c) => c.language);

    Widget seg(AppLanguage l) {
      final active = lang == l;
      return GestureDetector(
        onTap: () {
          if (context.read<SettingsController>().haptics) {
            HapticFeedback.selectionClick();
          }
          context.read<LanguageController>().setLanguage(l);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s16,
            vertical: AppTokens.s8,
          ),
          decoration: BoxDecoration(
            color: active ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l.short,
            style: TextStyle(
              color: active ? Colors.white : colors.ink3,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.s8),
            child: Icon(Icons.language, size: 18, color: colors.ink3),
          ),
          for (final l in AppLanguage.values) seg(l),
        ],
      ),
    );
  }
}
