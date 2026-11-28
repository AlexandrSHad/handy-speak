import 'package:flutter/material.dart';

import '../../core/app_version.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'accessibility_pane.dart';
import 'language_pane.dart';
import 'phrases_pane.dart';

/// The Settings dialog (ADDENDUM-05, ADR-0003) — the single surface where a
/// parent adjusts the app, divided into three categories reached from a rail
/// pinned to the leading edge:
///
/// - **Language** — the language set (main + optional second slot), the
///   voice-pack warnings and the manual refresh, plus the **disabled** Mood
///   voices row (IMPLEMENTATION_PLAN §2).
/// - **Phrases** — the show-shortcuts toggle and per-language phrase
///   management, with the add row pinned to the pane bottom.
/// - **Accessibility** — big letters, haptics, dark mode.
///
/// It is a popup dialog by nature and presents full-screen on screens too
/// small to frame it (`AppTokens.dialogMinScreenW/H`) — a change of
/// presentation, never of identity. Both presentations stay a [Dialog] and
/// never become a pushed route: the board has to remain in the tree beneath
/// the scrim (ADDENDUM-05 Risks).
void showSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    // `showModalBottomSheet` (what this replaced) defaults to
    // `useRootNavigator: false`; `showDialog` defaults to `true`. The
    // controllers this dialog reads are provided above the app's own
    // Navigator, so accepting the root-navigator default would build the
    // dialog outside their scope and every `context.watch` inside would
    // throw. Keep the navigator the bottom sheet this replaced used
    // (ADDENDUM-05 Risks).
    useRootNavigator: false,
    builder: (_) => const _SettingsDialog(),
  );
}

/// A top-level division of the Settings dialog. Exactly one is visible at a
/// time. Qualified per `CONTEXT.md` — the board's word groups are
/// `SymbolCategory`.
enum SettingsCategory { language, phrases, accessibility }

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  /// Always Language on open — the dialog never remembers where the parent
  /// was last time (ADDENDUM-05 step 3).
  SettingsCategory _category = SettingsCategory.language;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final screen = MediaQuery.sizeOf(context);

    // Two states, no interpolation: either the dialog fits with `s24` of
    // margin on every side, or it takes the whole screen.
    final fullScreen = screen.width < AppTokens.dialogMinScreenW ||
        screen.height < AppTokens.dialogMinScreenH;

    final content = Row(
      // Stretch, so the rail's `surface2` and the divider rule run the full
      // height of the dialog rather than only as far as the rail's content.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryRail(
          selected: _category,
          onSelect: (c) => setState(() => _category = c),
        ),
        VerticalDivider(width: 1, thickness: 1, color: colors.divider),
        Expanded(
          // All three panes stay MOUNTED and the stack just picks one to
          // show. A `switch` here returns a different widget type per
          // category, so every rail tap disposes the old pane's State: a
          // half-typed phrase in the add field is thrown away, and
          // `_LanguageSectionState.didChangeDependencies` re-fires
          // `_checkVoices()` on a fresh State every single time Language is
          // revisited — a `hasVoiceFor` TTS round-trip per configured slot
          // plus a spinner flash in the refresh button. The bottom sheet
          // this replaced had every section mounted at once and did neither;
          // keeping the panes alive restores that behaviour.
          //
          // Safe for AAC: `RenderIndexedStack.visitChildrenForSemantics`
          // visits only the displayed child (verified in the Flutter 3.44
          // SDK), so the hidden panes are never announced by a screen
          // reader. `_IndexedStackElement.debugVisitOnstageChildren` does the
          // same for the element tree, which is why the suites' default
          // `skipOffstage` finders still see exactly one pane. Focus follows
          // too: hidden children sit under `ExcludeFocus`, so the add field
          // gives up focus when Phrases is hidden and keeps only its text.
          // The children MUST stay in `SettingsCategory` declaration order —
          // `index` is the enum's `.index`.
          //
          // Deferred: what this actually preserves is dialog-scoped session
          // state (the phrase draft, the voice-probe fields), and
          // `IndexedStack` gets that lifetime as a side effect of keeping
          // widgets alive rather than by saying so. The honest shape is an
          // object owned by `_SettingsDialogState` and handed to the panes.
          // The natural moment — the Language section extracted into its
          // own file (C2) — has arrived; the hoisting itself is still
          // deferred.
          child: IndexedStack(
            index: _category.index,
            children: const [
              LanguagePane(),
              PhrasesPane(),
              AccessibilityPane(),
            ],
          ),
        ),
      ],
    );

    if (fullScreen) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: SizedBox(
          width: screen.width,
          height: screen.height,
          child: content,
        ),
      );
    }

    // Size lives here, not in the theme: the theme owns colour, shape and
    // clipping; the dialog owns which of its two presentations it is in.
    return Dialog(
      child: SizedBox(
        width: AppTokens.dialogW,
        height: AppTokens.dialogH,
        child: content,
      ),
    );
  }
}

/// The category rail. Content-sized and **unbounded by decision**
/// (ADDENDUM-05 Risks): a fixed width truncates `Nastavení` / `Доступність`
/// at text scale 1.3, which is the exact failure that disqualified top tabs.
/// So: [IntrinsicWidth] around the column, labels that can never wrap, and no
/// max-width clamp. Does not scroll — a title, three entries and the version
/// line at the foot always fit.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.selected, required this.onSelect});

  final SettingsCategory selected;
  final ValueChanged<SettingsCategory> onSelect;

  static const _icons = {
    SettingsCategory.language: Icons.language,
    SettingsCategory.phrases: Icons.chat_bubble_outline,
    SettingsCategory.accessibility: Icons.accessibility_new,
  };

  String _label(AppLocalizations l10n, SettingsCategory c) => switch (c) {
        SettingsCategory.language => l10n.settingsLanguage,
        SettingsCategory.phrases => l10n.settingsPhrases,
        SettingsCategory.accessibility => l10n.settingsAccessibility,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: colors.surface2,
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The dialog's own title lives here, not in the pane header —
            // the pane header carries the category title instead.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.s24, AppTokens.s16, AppTokens.s24, AppTokens.s16),
              child: Text(
                l10n.settings,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final c in SettingsCategory.values)
              _RailEntry(
                category: c,
                icon: _icons[c]!,
                label: _label(l10n, c),
                selected: c == selected,
                onTap: () => onSelect(c),
              ),
            // The rail's Column is bounded — the parent `Row` stretches it
            // inside the dialog's fixed-height `SizedBox` — so `Spacer`
            // pushes the version to the rail's foot rather than letting it
            // sit under the last entry. `Spacer` has zero intrinsic width,
            // so it does not disturb the surrounding `IntrinsicWidth`.
            const Spacer(),
            // This reopens the "rail footer note" slot ADDENDUM-05 rejected
            // from the design — but for different content: a version string,
            // not the design's note. Deliberately quiet (ink3, 12 pt, no
            // chrome) and unlocalized: the version reads the same in all three
            // locales, so it earns no ARB key.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.s24, AppTokens.s8, AppTokens.s24, AppTokens.s16),
              child: Text(
                'v$kAppVersion',
                key: const ValueKey('settingsVersion'),
                // Never wraps: the rail is `IntrinsicWidth` and unbounded.
                maxLines: 1,
                softWrap: false,
                style: TextStyle(color: colors.ink3, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailEntry extends StatelessWidget {
  const _RailEntry({
    required this.category,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final SettingsCategory category;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = selected ? colors.primary : colors.ink2;

    return Container(
      decoration: BoxDecoration(
        color: selected ? colors.primarySoft : Colors.transparent,
        // The selected bar rides the leading edge; it is drawn transparent
        // when unselected so the label never shifts on selection.
        border: BorderDirectional(
          start: BorderSide(
            color: selected ? colors.primary : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      // A transparent Material so the ink splash paints above the fill above
      // rather than on the Dialog's material underneath it.
      child: Material(
        color: Colors.transparent,
        // Settings is parent-facing: standard Material targets apply and
        // `ForgivingTap` is not required here — a documented exception to the
        // 72 pt child-facing `AppTokens.minTap`, registered in
        // `docs/forgiving-taps.md` (ADDENDUM-05 AAC checklist).
        child: InkWell(
          key: ValueKey('settingsCategory_${category.name}'),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.s16, AppTokens.s12, AppTokens.s24, AppTokens.s12),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: AppTokens.s12),
                // Never wraps: the rail is unbounded, so it never has to.
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
