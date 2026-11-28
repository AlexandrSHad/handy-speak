import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A settings toggle row: a bold name with a quieter description under it,
/// and the row's [Switch] at the trailing edge.
///
/// Pass `null` as [onChanged] to render the row disabled — dimmed, switch
/// frozen — which is how POC-deferred features stay visible.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
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

/// A section heading inside a pane: a bold title with an optional quieter
/// subtitle, grouping related rows under the pane header's category title.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
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
