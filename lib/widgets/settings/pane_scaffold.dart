import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Category title, optional subtitle and the close X — present in every
/// category, at the pane's trailing edge. Mirrors the header of the bottom
/// sheet this replaced.
class PaneHeader extends StatelessWidget {
  const PaneHeader({super.key, required this.title, this.subtitle});

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
class PaneScrollBody extends StatelessWidget {
  const PaneScrollBody({super.key, required this.child});

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
