import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../state/settings_controller.dart';
import 'pane_scaffold.dart';
import 'toggle_row.dart';

/// The Accessibility category pane: the big-letters/haptics/dark-mode rows
/// and the speech-feedback group, under the Accessibility pane header.
class AccessibilityPane extends StatelessWidget {
  const AccessibilityPane({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();

    return Column(
      children: [
        PaneHeader(
          title: l10n.settingsAccessibility,
          subtitle: l10n.settingsAccessibilityDesc,
        ),
        // No inner section header for the three original rows: the pane
        // header already says Accessibility (ADDENDUM-05 step 3). The speech
        // feedback group is different — four related toggles that would read
        // as a wall of switches without their own subgroup title.
        Expanded(
          child: PaneScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToggleRow(
                  name: l10n.settingsBigLettersName,
                  desc: l10n.settingsBigLettersDesc,
                  value: settings.bigLetters,
                  onChanged: (v) =>
                      context.read<SettingsController>().setBigLetters(v),
                ),
                ToggleRow(
                  name: l10n.settingsHapticName,
                  desc: l10n.settingsHapticDesc,
                  value: settings.haptics,
                  onChanged: (v) =>
                      context.read<SettingsController>().setHaptics(v),
                ),
                ToggleRow(
                  name: l10n.settingsDarkName,
                  desc: l10n.settingsDarkDesc,
                  value: settings.dark,
                  onChanged: (v) =>
                      context.read<SettingsController>().setDark(v),
                ),
                const SizedBox(height: AppTokens.s32),
                SectionTitle(l10n.settingsSpeechFeedback),
                ToggleRow(
                  name: l10n.settingsSpeakLettersName,
                  desc: l10n.settingsSpeakLettersDesc,
                  value: settings.speakLetters,
                  onChanged: (v) => context
                      .read<SettingsController>()
                      .setSpeakLetters(v),
                ),
                ToggleRow(
                  name: l10n.settingsSpeakWordsName,
                  desc: l10n.settingsSpeakWordsDesc,
                  value: settings.speakWords,
                  onChanged: (v) => context
                      .read<SettingsController>()
                      .setSpeakWords(v),
                ),
                ToggleRow(
                  name: l10n.settingsSpeakSymbolsName,
                  desc: l10n.settingsSpeakSymbolsDesc,
                  value: settings.speakSymbols,
                  onChanged: (v) => context
                      .read<SettingsController>()
                      .setSpeakSymbols(v),
                ),
                ToggleRow(
                  name: l10n.settingsSpeakPhrasesName,
                  desc: l10n.settingsSpeakPhrasesDesc,
                  value: settings.speakPhrases,
                  onChanged: (v) => context
                      .read<SettingsController>()
                      .setSpeakPhrases(v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
