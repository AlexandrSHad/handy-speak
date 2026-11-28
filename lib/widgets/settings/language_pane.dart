import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/speech_service.dart';
import '../../state/language_controller.dart';
import '../../state/settings_controller.dart';
import '../notice_banner.dart';
import 'language_dropdown_field.dart';
import 'pane_scaffold.dart';
import 'toggle_row.dart';

/// The Language category pane: the language-set section (main + optional
/// second slot, with its voice probes) and the Voice section, under the
/// Language pane header.
class LanguagePane extends StatelessWidget {
  const LanguagePane({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        PaneHeader(title: l10n.settingsLanguage),
        const Expanded(
          child: PaneScrollBody(
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
              child: SectionTitle(l10n.settingsLanguageSet,
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
        SectionTitle(l10n.settingsMainLangName,
            subtitle: l10n.settingsMainLangDesc),
        LanguageDropdownField(
          slot: 'main',
          value: controller.mainLang,
          items: AppLanguage.values,
          onChanged: controller.setMainLang,
        ),
        if (_mainHasVoice == false)
          NoticeBanner(
              text: l10n.voiceMissingNamed(controller.mainLang.nativeName)),
        const SizedBox(height: AppTokens.s16),
        ToggleRow(
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
          LanguageDropdownField(
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

class _VoiceSection extends StatelessWidget {
  const _VoiceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.settingsVoice),
        // Mood voices: present but OFF + disabled for the POC (§2).
        ToggleRow(
          name: l10n.settingsMoodName,
          desc: l10n.settingsMoodDesc,
          value: settings.moodEnabled,
          onChanged: null,
        ),
      ],
    );
  }
}
