import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/speech_service.dart';
import '../state/composer_controller.dart';
import '../state/settings_controller.dart';
import 'keyboard_view.dart';
import 'math_board.dart';
import 'message_bar.dart';
import 'notice_banner.dart';
import 'phrase_strip.dart';
import 'settings_sheet.dart';
import 'symbol_board.dart';
import 'top_bar.dart';

/// The app shell, laid out for a landscape tablet (IMPLEMENTATION_PLAN Task 3).
/// Uses Expanded/Flexible so keyboard + message bar + phrase strip + symbol
/// grid all fit a 16:9 panel without overflow (§6.1.3).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ComposerController, InputMode>((c) => c.mode);
    final showPhrases =
        context.select<SettingsController, bool>((s) => s.showPhrases);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Column(
            children: [
              TopBar(onOpenSettings: () => showSettingsSheet(context)),
              const SizedBox(height: AppTokens.s16),
              const MessageBar(),
              const SizedBox(height: AppTokens.s12),
              // Hard failure: the engine never bound. Tell the parent why the
              // app can't speak and where to fix it.
              if (context.select<SpeechService, bool>(
                  (s) => s.status == SpeechStatus.unavailable)) ...[
                NoticeBanner(
                  text: AppLocalizations.of(context)!.voiceUnavailableDetail,
                  kind: NoticeKind.error,
                ),
                const SizedBox(height: AppTokens.s12),
              ],
              if (showPhrases) ...[
                const PhraseStrip(),
                const SizedBox(height: AppTokens.s12),
              ],
              Expanded(
                child: switch (mode) {
                  InputMode.keyboard => const KeyboardView(),
                  InputMode.math => const MathBoard(),
                  InputMode.symbols => const SymbolBoard(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
