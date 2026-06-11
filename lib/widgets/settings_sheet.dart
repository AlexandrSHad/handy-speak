import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_language.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/speech_service.dart';
import '../state/language_controller.dart';
import '../state/phrases_controller.dart';
import '../state/settings_controller.dart';

/// Settings sheet (IMPLEMENTATION_PLAN Task 8): language selector, the
/// **disabled** Mood voices row (§2), dark/haptic toggles, per-language phrase
/// management, and the Czech voice-missing warning.
void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTokens.s24),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.rCard),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.s24, AppTokens.s16, AppTokens.s12, AppTokens.s8),
              child: Row(
                children: [
                  Text(
                    l10n.settings,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.ink2),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppTokens.s24),
                children: const [
                  _LanguageSection(),
                  SizedBox(height: AppTokens.s32),
                  _VoiceSection(),
                  SizedBox(height: AppTokens.s32),
                  _PhrasesSection(),
                  SizedBox(height: AppTokens.s32),
                  _AccessibilitySection(),
                  SizedBox(height: AppTokens.s24),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final lang = context.watch<LanguageController>().language;
    final speech = context.watch<SpeechService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.settingsLanguage, subtitle: l10n.settingsLanguageDesc),
        for (final l in AppLanguage.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.s8),
            child: Material(
              color: lang == l ? colors.primarySoft : colors.surface2,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                // §6.1.1 — switching here also clears the message.
                onTap: () => context.read<LanguageController>().setLanguage(l),
                child: Container(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: lang == l ? colors.primary : colors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.divider),
                        ),
                        child: Text(l.short,
                            style: TextStyle(
                                color: colors.ink2,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: AppTokens.s12),
                      Text(
                        l.nativeName,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (lang == l)
                        Icon(Icons.check_circle, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (lang == AppLanguage.cs && !speech.csAvailable)
          _VoiceWarning(text: l10n.voiceMissing),
      ],
    );
  }
}

class _VoiceWarning extends StatelessWidget {
  const _VoiceWarning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: AppTokens.s8),
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.volume_off_outlined, size: 20, color: colors.ink2),
          const SizedBox(width: AppTokens.s8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: colors.ink2, fontSize: 14, height: 1.4)),
          ),
        ],
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

class _AccessibilitySection extends StatelessWidget {
  const _AccessibilitySection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.settingsAccessibility),
        _ToggleRow(
          name: l10n.settingsBigLettersName,
          desc: l10n.settingsBigLettersDesc,
          value: settings.bigLetters,
          onChanged: (v) => context.read<SettingsController>().setBigLetters(v),
        ),
        _ToggleRow(
          name: l10n.settingsHapticName,
          desc: l10n.settingsHapticDesc,
          value: settings.haptics,
          onChanged: (v) => context.read<SettingsController>().setHaptics(v),
        ),
        _ToggleRow(
          name: l10n.settingsDarkName,
          desc: l10n.settingsDarkDesc,
          value: settings.dark,
          onChanged: (v) => context.read<SettingsController>().setDark(v),
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
  });

  final String name;
  final String desc;
  final bool value;
  final ValueChanged<bool>? onChanged;

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
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _PhrasesSection extends StatefulWidget {
  const _PhrasesSection();

  @override
  State<_PhrasesSection> createState() => _PhrasesSectionState();
}

class _PhrasesSectionState extends State<_PhrasesSection> {
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.settingsPhrases),
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
                    child: Icon(Icons.push_pin, size: 16, color: colors.primary),
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
                    style: TextStyle(color: colors.ink3, fontSize: 12)),
                TextButton(
                  onPressed: () =>
                      context.read<PhrasesController>().togglePin(lang, p),
                  child: Text(p.pinned ? l10n.settingsUnpin : l10n.settingsPin),
                ),
                IconButton(
                  onPressed: () =>
                      context.read<PhrasesController>().remove(lang, p),
                  icon: Icon(Icons.close, size: 20, color: colors.ink3),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppTokens.s8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => add(),
                decoration: InputDecoration(
                  hintText: l10n.settingsAddPhrase,
                  filled: true,
                  fillColor: colors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.divider),
                  ),
                ),
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
      ],
    );
  }
}
