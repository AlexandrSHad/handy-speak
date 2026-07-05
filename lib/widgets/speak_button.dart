import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/math_speak.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/speech_service.dart';
import '../state/composer_controller.dart';
import '../state/language_controller.dart';
import '../state/settings_controller.dart';

/// Default-voice Speak button (IMPLEMENTATION_PLAN Task 4).
///
/// Reflects [SpeechService.status] so the child always sees honest state:
///  - while the engine is still binding it is disabled and — after a short
///    delay, to avoid flashing on fast starts — shows a spinner + "Preparing…";
///  - if the engine never binds it shows a disabled "Voice unavailable" state
///    (paired with an error banner on the home screen);
///  - once ready it behaves as before: disabled when the message is empty,
///    "Speaking…" while [SpeechService.isSpeaking].
class SpeakButton extends StatefulWidget {
  const SpeakButton({super.key});

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  /// Don't flash a spinner for a bind that finishes quickly — only show it once
  /// the wait is long enough to be worth acknowledging.
  static const _spinnerDelay = Duration(milliseconds: 400);

  Timer? _spinnerTimer;
  bool _spinnerDue = false;

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  /// Arm the delay timer only while the engine is actually binding, and tear it
  /// down the moment it isn't — so a ready/unavailable start never leaves a
  /// pending timer (which would also keep the infinite spinner out of tests).
  void _syncSpinnerTimer(SpeechStatus status) {
    if (status == SpeechStatus.initializing) {
      _spinnerTimer ??= Timer(_spinnerDelay, () {
        if (mounted) setState(() => _spinnerDue = true);
      });
    } else {
      _spinnerTimer?.cancel();
      _spinnerTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final speech = context.watch<SpeechService>();
    final status = speech.status;
    final speaking = speech.isSpeaking;
    final hasText = context
        .select<ComposerController, bool>((c) => c.text.trim().isNotEmpty);

    _syncSpinnerTimer(status);

    final unavailable = status == SpeechStatus.unavailable;
    final showSpinner = status == SpeechStatus.initializing && _spinnerDue;
    final enabled = status == SpeechStatus.ready && hasText;

    final IconData iconData;
    final String label;
    if (unavailable) {
      iconData = Icons.volume_off_rounded;
      label = l10n.voiceUnavailable;
    } else if (showSpinner) {
      iconData = Icons.volume_up_rounded; // hidden behind the spinner below
      label = l10n.preparingVoice;
    } else if (speaking) {
      iconData = Icons.graphic_eq;
      label = l10n.speaking;
    } else {
      iconData = Icons.volume_up_rounded;
      label = l10n.speak;
    }

    return SizedBox(
      height: AppTokens.minTap,
      child: FilledButton.icon(
        onPressed: enabled
            ? () {
                if (context.read<SettingsController>().haptics) {
                  HapticFeedback.selectionClick();
                }
                final composer = context.read<ComposerController>();
                // In math mode the raw glyphs (`× ÷ = < >`) are pronounced
                // unreliably by flutter_tts, so translate to words first
                // (ADDENDUM-02). Numbers pass through; mood rate/pitch ride
                // on top unchanged.
                final toSpeak = composer.mode == InputMode.math
                    ? mathSpeak(composer.text,
                        context.read<LanguageController>().language)
                    : composer.text;
                context.read<SpeechService>().speak(toSpeak);
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
        icon: showSpinner
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              )
            : Icon(iconData, size: 26),
        label: Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
