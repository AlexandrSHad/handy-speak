import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/theme.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/l10n/app_localizations_uk.dart';

// Pure-unit coverage for the Settings dialog's string and layout contracts
// (testing-strategy §4 "Settings · Unit"). No widget tree is pumped: these
// assert the generated l10n values and the size→presentation breakpoint that
// `_SettingsDialogState.build` computes, so the fast tier pins them before the
// behavior tier leans on them.

/// Mirrors the breakpoint logic inlined in `_SettingsDialogState.build`:
/// the dialog goes full-screen the moment either dimension drops below the
/// framed-dialog-plus-margin size. Kept as a local helper (the widget computes
/// it inline, so there is no exported function to call), driven by the real
/// [AppTokens] so the boundary tracks the tokens, not a copied literal.
bool isFullScreenFor(Size screen) =>
    screen.width < AppTokens.dialogMinScreenW ||
    screen.height < AppTokens.dialogMinScreenH;

void main() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();
  final uk = AppLocalizationsUk();

  group('Settings labels — no parent/child tier', () {
    test('the phrases label carries no "Parent" prefix in any locale', () {
      // The prefix modelled a parent/child settings tier CONTEXT.md says must
      // not be modelled (ADDENDUM-05 step 2).
      expect(en.settingsPhrases, 'Phrases');
      expect(cs.settingsPhrases, 'Fráze');
      expect(uk.settingsPhrases, 'Фрази');

      for (final label in [
        en.settingsPhrases,
        cs.settingsPhrases,
        uk.settingsPhrases,
      ]) {
        expect(label, isNot(contains('Parent')));
        expect(label, isNot(contains('Rodič')));
        expect(label, isNot(contains('Батьки')));
      }
    });
  });

  group('Dialog breakpoint derives from the dialog size', () {
    test('the breakpoint tokens are the dialog size plus s24 margin all round',
        () {
      // Assert the RELATIONSHIP, never the literals: the breakpoint is the
      // framed dialog plus `s24` of margin on every side, so the two can never
      // drift apart (ADR-0003).
      expect(AppTokens.dialogMinScreenW, AppTokens.dialogW + AppTokens.s24 * 2);
      expect(AppTokens.dialogMinScreenH, AppTokens.dialogH + AppTokens.s24 * 2);
    });

    test('exactly at the breakpoint the dialog stays framed (strict <)', () {
      expect(
        isFullScreenFor(const Size(
          AppTokens.dialogMinScreenW,
          AppTokens.dialogMinScreenH,
        )),
        isFalse,
      );
    });

    test('a hair under either dimension flips it to full screen', () {
      // Width just under, height fine.
      expect(
        isFullScreenFor(const Size(
          AppTokens.dialogMinScreenW - 0.1,
          AppTokens.dialogMinScreenH,
        )),
        isTrue,
      );
      // Height just under, width fine.
      expect(
        isFullScreenFor(const Size(
          AppTokens.dialogMinScreenW,
          AppTokens.dialogMinScreenH - 0.1,
        )),
        isTrue,
      );
    });

    test('a comfortable tablet viewport stays framed, a small one fills', () {
      expect(isFullScreenFor(const Size(1280, 800)), isFalse);
      expect(isFullScreenFor(const Size(900, 600)), isTrue);
    });
  });

  group('New settings l10n keys resolve per locale', () {
    test('settingsLanguageSet / settingsPhrasesDesc / '
        'settingsAccessibilityDesc are non-empty and distinctly translated',
        () {
      final byKey = <String, List<String>>{
        'settingsLanguageSet': [
          en.settingsLanguageSet,
          cs.settingsLanguageSet,
          uk.settingsLanguageSet,
        ],
        'settingsPhrasesDesc': [
          en.settingsPhrasesDesc,
          cs.settingsPhrasesDesc,
          uk.settingsPhrasesDesc,
        ],
        'settingsAccessibilityDesc': [
          en.settingsAccessibilityDesc,
          cs.settingsAccessibilityDesc,
          uk.settingsAccessibilityDesc,
        ],
      };

      byKey.forEach((key, values) {
        for (final v in values) {
          expect(v.trim(), isNotEmpty, reason: '$key is blank in some locale');
        }
        // Three distinct translations — a copy-paste of the English into a
        // secondary ARB would slip through a mere non-empty check.
        expect(values.toSet(), hasLength(3),
            reason: '$key is not translated per locale: $values');
      });
    });
  });
}
