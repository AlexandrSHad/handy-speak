import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Severity of a [NoticeBanner].
enum NoticeKind {
  /// Soft, recoverable hint — e.g. a missing Czech voice pack.
  warning,

  /// Hard failure — e.g. text-to-speech unavailable on this device.
  error,
}

/// Inline status banner. Promoted out of the settings sheet so the Speak area
/// can reuse the same styling for the "voice unavailable" error while settings
/// keeps using it for the softer "no Czech voice" warning.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.text,
    this.kind = NoticeKind.warning,
  });

  final String text;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isError = kind == NoticeKind.error;

    final accent = isError ? colors.danger : colors.accent;
    final background =
        isError ? colors.danger.withValues(alpha: 0.12) : colors.accentSoft;
    final icon = isError ? Icons.error_outline : Icons.volume_off_outlined;

    return Container(
      margin: const EdgeInsets.only(top: AppTokens.s8),
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isError ? accent : colors.ink2),
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
