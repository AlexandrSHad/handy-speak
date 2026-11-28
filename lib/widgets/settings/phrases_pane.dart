import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../state/language_controller.dart';
import '../../state/phrases_controller.dart';
import '../../state/settings_controller.dart';
import '../notice_banner.dart';
import 'pane_scaffold.dart';
import 'toggle_row.dart';

/// The Phrases category. One State owns both the scrolling list and the
/// pinned add row, so the `TextEditingController` and `add()` behaviour are
/// exactly what the bottom sheet this replaced had. The add row sits
/// **outside** the scroll view (ADDENDUM-05 step 3) because the phrase list is
/// uncapped — pinned to the pane bottom it is always reachable without
/// scrolling.
class PhrasesPane extends StatefulWidget {
  const PhrasesPane({super.key});

  @override
  State<PhrasesPane> createState() => _PhrasesPaneState();
}

class _PhrasesPaneState extends State<PhrasesPane> {
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
        PaneHeader(
          title: l10n.settingsPhrases,
          subtitle: l10n.settingsPhrasesDesc,
        ),
        // No inner section header: the pane header already says Phrases.
        Expanded(
          child: PaneScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Save-failure channel (S02-issue-C3 item 3): the
                // controller exposes the transient save-failure state,
                // this pane already watches it — one conditional banner,
                // cleared by the next successful save.
                if (phrasesCtrl.saveFailed)
                  NoticeBanner(
                    kind: NoticeKind.error,
                    text: l10n.settingsPhrasesSaveFailed,
                  ),
                ToggleRow(
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
                        // The "N× used" count was removed with the `uses`
                        // field (M2, owner decision 2026-11-28): the counter
                        // was never incremented, so the number shown here
                        // was a frozen seed fabrication.
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
