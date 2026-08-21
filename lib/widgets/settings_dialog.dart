import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_language.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/speech_service.dart';
import '../state/language_controller.dart';
import '../state/phrases_controller.dart';
import '../state/settings_controller.dart';
import 'notice_banner.dart';

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
          // The natural moment is when this ~1000-line file gets the
          // Language section extracted into its own file.
          child: IndexedStack(
            index: _category.index,
            children: const [
              _LanguagePane(),
              _PhrasesPane(),
              _AccessibilityPane(),
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
/// max-width clamp. Does not scroll — three entries plus a title always fit.
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

/// Category title, optional subtitle and the close X — present in every
/// category, at the pane's trailing edge. Mirrors the header of the bottom
/// sheet this replaced.
class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTokens.s24, AppTokens.s16, AppTokens.s12, AppTokens.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTokens.s4),
                      // Same measure cap as the body, for the same reason:
                      // a line of prose must not run the full dialog width.
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: AppTokens.measureMax),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                              color: colors.ink3, fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.closeLabel,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: colors.ink2),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// The scrolling part of a pane. Content is capped at a
/// [AppTokens.measureMax] measure and left-aligned — the full-width text
/// measure is what motivated the redesign (ADR-0003).
///
/// The key sits on the scroll view itself, so a suite that needs the
/// `Scrollable` (e.g. `tester.scrollUntilVisible`) resolves it as:
/// `find.descendant(of: find.byKey(const ValueKey('settingsPaneScrollable')),
/// matching: find.byType(Scrollable))`.
class _PaneScrollBody extends StatelessWidget {
  const _PaneScrollBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('settingsPaneScrollable'),
      padding: const EdgeInsets.all(AppTokens.s24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTokens.measureMax),
          child: child,
        ),
      ),
    );
  }
}

class _LanguagePane extends StatelessWidget {
  const _LanguagePane();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _PaneHeader(title: l10n.settingsLanguage),
        const Expanded(
          child: _PaneScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LanguageSection(),
                SizedBox(height: AppTokens.s32),
                _VoiceSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessibilityPane extends StatelessWidget {
  const _AccessibilityPane();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();

    return Column(
      children: [
        _PaneHeader(
          title: l10n.settingsAccessibility,
          subtitle: l10n.settingsAccessibilityDesc,
        ),
        // No inner section header: the pane header already says
        // Accessibility (ADDENDUM-05 step 3).
        Expanded(
          child: _PaneScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ToggleRow(
                  name: l10n.settingsBigLettersName,
                  desc: l10n.settingsBigLettersDesc,
                  value: settings.bigLetters,
                  onChanged: (v) =>
                      context.read<SettingsController>().setBigLetters(v),
                ),
                _ToggleRow(
                  name: l10n.settingsHapticName,
                  desc: l10n.settingsHapticDesc,
                  value: settings.haptics,
                  onChanged: (v) =>
                      context.read<SettingsController>().setHaptics(v),
                ),
                _ToggleRow(
                  name: l10n.settingsDarkName,
                  desc: l10n.settingsDarkDesc,
                  value: settings.dark,
                  onChanged: (v) =>
                      context.read<SettingsController>().setDark(v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppTokens.s4),
          Text(
            subtitle!,
            style: TextStyle(color: colors.ink3, fontSize: 14, height: 1.4),
          ),
        ],
        const SizedBox(height: AppTokens.s12),
      ],
    );
  }
}

/// Language set slots (ADDENDUM-04): the parent configures a **main**
/// language plus an optional **second** language — a dropdown per slot and
/// a Switch that adds/removes the second language (the only removal path,
/// Q12). The main dropdown swaps instead of colliding when the parent picks
/// the current second language. Checks each configured slot for an
/// installed voice on open and on every set change (mirrors the listener
/// pattern in `keyboard_view.dart`'s `_numOpen`), plus a manual refresh
/// action. Shows the persistent unsupported-device-language banner (Q13)
/// when first-run seeding fell back to `en`.
class _LanguageSection extends StatefulWidget {
  const _LanguageSection();

  @override
  State<_LanguageSection> createState() => _LanguageSectionState();
}

class _LanguageSectionState extends State<_LanguageSection> {
  bool? _mainHasVoice;
  bool? _secondHasVoice;
  bool _checking = false;

  /// Bumped at the start of every [_checkVoices] call; a stale call whose
  /// generation no longer matches on completion (superseded by a newer pair
  /// change before it resolved) discards its result instead of overwriting
  /// a more recent one.
  int _checkGeneration = 0;

  LanguageController? _controller;
  AppLanguage? _lastMain;
  AppLanguage? _lastSecond;

  // Also tracked (not just the pair): SpeechService starts `initializing`
  // and only reaches `ready` up to ~16s later. If Settings opens in that
  // window, `hasVoiceFor` fail-opens (no warning) — re-checking once the
  // engine is actually ready is the only way the banner can still appear.
  SpeechService? _speech;
  SpeechStatus? _lastSpeechStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var shouldCheck = false;

    final controller = context.read<LanguageController>();
    if (_controller != controller) {
      _controller?.removeListener(_onSetChanged);
      _controller = controller;
      _controller!.addListener(_onSetChanged);
      _lastMain = controller.mainLang;
      _lastSecond = controller.secondLang;
      shouldCheck = true;
    }

    final speech = context.read<SpeechService>();
    if (_speech != speech) {
      _speech?.removeListener(_onSpeechChanged);
      _speech = speech;
      _speech!.addListener(_onSpeechChanged);
      _lastSpeechStatus = speech.status;
      shouldCheck = true;
    }

    if (shouldCheck) _checkVoices();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onSetChanged);
    _speech?.removeListener(_onSpeechChanged);
    super.dispose();
  }

  void _onSetChanged() {
    final c = _controller!;
    if (c.mainLang != _lastMain || c.secondLang != _lastSecond) {
      _lastMain = c.mainLang;
      _lastSecond = c.secondLang;
      _checkVoices();
    }
  }

  void _onSpeechChanged() {
    final status = _speech!.status;
    if (status != _lastSpeechStatus) {
      _lastSpeechStatus = status;
      if (status == SpeechStatus.ready) _checkVoices();
    }
  }

  Future<void> _checkVoices() async {
    final generation = ++_checkGeneration;
    final speech = _speech!;
    final main = _controller!.mainLang;
    final second = _controller!.secondLang;
    setState(() => _checking = true);
    // No second language (single-language mode): treat the slot as voiced —
    // the warning only applies to configured slots.
    final results = await Future.wait([
      speech.hasVoiceFor(main),
      second == null ? Future<bool>.value(true) : speech.hasVoiceFor(second),
    ]);
    if (!mounted || generation != _checkGeneration) return;
    setState(() {
      _mainHasVoice = results[0];
      _secondHasVoice = results[1];
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<LanguageController>();

    // The device language named for the banner. intl 0.20.2 ships no CLDR
    // display names and dart:ui `Locale` has no `displayName`, so the name
    // is the uppercase language code (e.g. "DE", "PL") — unambiguous and
    // locale-independent. Revisit if a locale-display-name source lands.
    String deviceLangName() {
      final locale = controller.deviceLocale;
      return locale?.languageCode.toUpperCase() ?? '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              // The section is the language *set*; the pane header already
              // says Language (ADDENDUM-05 step 3).
              child: _SectionTitle(l10n.settingsLanguageSet,
                  subtitle: l10n.settingsLanguageDesc),
            ),
            // Stays in the section header, not the pane header: it refreshes
            // the voice checks for these slots, nothing else.
            IconButton(
              tooltip: l10n.settingsRefreshVoices,
              onPressed: _checking ? null : _checkVoices,
              icon: _checking
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.ink3,
                      ),
                    )
                  : Icon(Icons.refresh, color: colors.ink3),
            ),
          ],
        ),
        if (controller.deviceLangUnsupported)
          NoticeBanner(
              text: l10n.settingsUnsupportedDeviceLang(deviceLangName())),
        _SectionTitle(l10n.settingsMainLangName,
            subtitle: l10n.settingsMainLangDesc),
        _LanguageDropdownField(
          slot: 'main',
          value: controller.mainLang,
          items: AppLanguage.values,
          onChanged: controller.setMainLang,
        ),
        if (_mainHasVoice == false)
          NoticeBanner(
              text: l10n.voiceMissingNamed(controller.mainLang.nativeName)),
        const SizedBox(height: AppTokens.s16),
        _ToggleRow(
          switchKey: const ValueKey('settingsSecondLangSwitch'),
          name: l10n.settingsSecondLangName,
          desc: l10n.settingsSecondLangDesc,
          value: controller.secondLang != null,
          onChanged: controller.setSecondEnabled,
        ),
        if (controller.secondLang != null) ...[
          const SizedBox(height: AppTokens.s4),
          // Q12: no "None" item — the Switch above is the only removal path;
          // the dropdown never offers the main language.
          _LanguageDropdownField(
            slot: 'second',
            value: controller.secondLang!,
            items: [
              for (final l in AppLanguage.values)
                if (l != controller.mainLang) l,
            ],
            onChanged: controller.setSecondLang,
          ),
          if (_secondHasVoice == false)
            NoticeBanner(
                text:
                    l10n.voiceMissingNamed(controller.secondLang!.nativeName)),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.s4),
            child: Text(
              l10n.settingsSecondOffHint,
              style:
                  TextStyle(color: colors.ink3, fontSize: 13, height: 1.4),
            ),
          ),
      ],
    );
  }
}

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
class _LanguageDropdownField extends StatelessWidget {
  const _LanguageDropdownField({
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

class _VoiceSection extends StatelessWidget {
  const _VoiceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.settingsVoice),
        // Mood voices: present but OFF + disabled for the POC (§2).
        _ToggleRow(
          name: l10n.settingsMoodName,
          desc: l10n.settingsMoodDesc,
          value: settings.moodEnabled,
          onChanged: null,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.name,
    required this.desc,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  final String name;
  final String desc;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Optional key for the row's [Switch] (widget tests tap it by key).
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = onChanged == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.s8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: colors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          color: colors.ink3, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.s16),
            Switch(key: switchKey, value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The Phrases category. One State owns both the scrolling list and the
/// pinned add row, so the `TextEditingController` and `add()` behaviour are
/// exactly what the bottom sheet this replaced had. The add row sits
/// **outside** the scroll view (ADDENDUM-05 step 3) because the phrase list is
/// uncapped — pinned to the pane bottom it is always reachable without
/// scrolling.
class _PhrasesPane extends StatefulWidget {
  const _PhrasesPane();

  @override
  State<_PhrasesPane> createState() => _PhrasesPaneState();
}

class _PhrasesPaneState extends State<_PhrasesPane> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final lang = context.watch<LanguageController>().language;
    final phrasesCtrl = context.watch<PhrasesController>();
    final settings = context.watch<SettingsController>();
    final phrases = phrasesCtrl.phrasesFor(lang);

    void add() {
      context.read<PhrasesController>().add(lang, _controller.text);
      _controller.clear();
    }

    return Column(
      children: [
        _PaneHeader(
          title: l10n.settingsPhrases,
          subtitle: l10n.settingsPhrasesDesc,
        ),
        // No inner section header: the pane header already says Phrases.
        Expanded(
          child: _PaneScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ToggleRow(
                  name: l10n.settingsShowPhrasesName,
                  desc: l10n.settingsShowPhrasesDesc,
                  value: settings.showPhrases,
                  onChanged: (v) =>
                      context.read<SettingsController>().setShowPhrases(v),
                ),
                if (!settings.showPhrases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.s8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.visibility_off_outlined,
                            size: 16, color: colors.ink3),
                        const SizedBox(width: AppTokens.s8),
                        Expanded(
                          child: Text(
                            l10n.settingsPhrasesHiddenNote,
                            style: TextStyle(
                                color: colors.ink3, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppTokens.s8),
                for (final p in phrases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.s8),
                    child: Row(
                      children: [
                        if (p.pinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.push_pin,
                                size: 16, color: colors.primary),
                          ),
                        Expanded(
                          child: Text(
                            p.text,
                            style: TextStyle(
                                color: colors.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${p.uses}× ${l10n.settingsUsed}',
                            style:
                                TextStyle(color: colors.ink3, fontSize: 12)),
                        TextButton(
                          onPressed: () =>
                              context.read<PhrasesController>().togglePin(
                                    lang,
                                    p,
                                  ),
                          child: Text(
                              p.pinned ? l10n.settingsUnpin : l10n.settingsPin),
                        ),
                        IconButton(
                          onPressed: () =>
                              context.read<PhrasesController>().remove(lang, p),
                          icon: Icon(Icons.close, size: 20, color: colors.ink3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Pinned add bar. Capped at the same measure as the body so the
        // field does not run the full dialog width, and never height-
        // constrained — the addendum04 tests assert it matches the language
        // dropdown at text scales 1.0 and 1.3.
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.divider)),
          ),
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppTokens.measureMax),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('settingsAddPhraseField'),
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => add(),
                      decoration:
                          InputDecoration(hintText: l10n.settingsAddPhrase),
                    ),
                  ),
                  const SizedBox(width: AppTokens.s8),
                  FilledButton(
                    onPressed: add,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s24, vertical: AppTokens.s16),
                    ),
                    child: Text(l10n.settingsAdd),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
