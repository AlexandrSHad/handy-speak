import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_language.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../state/composer_controller.dart';
import '../state/language_controller.dart';
import '../state/settings_controller.dart';

/// Brand, Keyboard/Symbols toggle, language-set toggle (hidden in
/// single-language mode) and a settings button (IMPLEMENTATION_PLAN Task 3).
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final dual = context.select<LanguageController, bool>(
        (c) => c.set.length > 1);

    return Row(
      children: [
        _Brand(),
        const Spacer(),
        const _ModeToggle(),
        const Spacer(),
        // Q15: single-language mode hides the toggle entirely and the
        // Spacers reflow the row naturally — no extra styling.
        if (dual) ...[
          const _LanguageToggle(),
          const SizedBox(width: AppTokens.s12),
        ],
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
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
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
          seg(InputMode.math, Icons.calculate_outlined, l10n.modeMath),
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
    final l10n = AppLocalizations.of(context)!;
    // Watching (not selecting) because both `language` and the set-derived
    // `set` list are read here — a single ChangeNotifier rebuild covers
    // both. Only reachable in two-language mode; TopBar hides the toggle
    // entirely when the set has no second language.
    final controller = context.watch<LanguageController>();
    final lang = controller.language;
    final languages = controller.set;

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

    return Semantics(
      label: l10n.settingsLanguage,
      child: Container(
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
            for (final l in languages) seg(l),
          ],
        ),
      ),
    );
  }
}
