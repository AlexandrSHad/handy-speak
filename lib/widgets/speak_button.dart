import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/speech_service.dart';
import '../state/composer_controller.dart';
import '../state/settings_controller.dart';

/// Default-voice Speak button (IMPLEMENTATION_PLAN Task 4). Disabled when the
/// message is empty; shows a "Speaking…" state while [SpeechService.isSpeaking].
class SpeakButton extends StatelessWidget {
  const SpeakButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final speech = context.watch<SpeechService>();
    final text = context.select<ComposerController, String>((c) => c.text);
    final enabled = text.trim().isNotEmpty;
    final speaking = speech.isSpeaking;

    return SizedBox(
      height: AppTokens.minTap,
      child: FilledButton.icon(
        onPressed: enabled
            ? () {
                if (context.read<SettingsController>().haptics) {
                  HapticFeedback.selectionClick();
                }
                // The engine locale was set on language switch; the POC always
                // speaks with the engine default rate/pitch (moods off, §2).
                context.read<SpeechService>().speak(text);
              }
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: speaking ? colors.primaryPress : colors.primary,
          disabledBackgroundColor: colors.surface3,
          foregroundColor: Colors.white,
          disabledForegroundColor: colors.ink3,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMessage),
          ),
        ),
        icon: Icon(speaking ? Icons.graphic_eq : Icons.volume_up_rounded,
            size: 26),
        label: Text(
          speaking ? l10n.speaking : l10n.speak,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
