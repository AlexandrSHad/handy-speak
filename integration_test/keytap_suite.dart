import 'dart:ui' show Offset, Rect;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/state/composer_controller.dart';

import 'addendum01_suite.dart';

/// Locks in the desired press semantics for on-screen keyboard keys.
///
/// The bug: `_CharKey` (lib/widgets/keyboard_view.dart) uses `InkWell.onTap`.
/// Flutter's TapGestureRecognizer CANCELS the tap as soon as the pointer
/// drifts more than `kTouchSlop` (~18 logical px) before lift-off — but the
/// ink ripple already started on pointer-down. Result: the key visibly
/// responds (ripple) yet inserts nothing. Shaky or sliding fingers — exactly
/// the users this app targets — hit this constantly.
///
/// Desired semantics encoded here (a later job implements them):
///   * A press RELEASED WITHIN THE KEY BOUNDS inserts the letter, no matter
///     how far the pointer wandered on the way.
///   * Sliding OFF the key and releasing elsewhere inserts nothing.
///
/// Until the fix lands, the "slides within the key" tests are expected to
/// FAIL — they reproduce the dropped-key bug. The control, slide-off and
/// rollover tests must be green before and after the fix.
///
/// Shared between `test/keytap_test.dart` (headless `flutter test`) and
/// `integration_test/keytap_test.dart` (on-device / web). Deliberately does
/// NOT initialise any binding — each entry point does its own.
void runKeyTapSuite() {
  final en = AppLocalizationsEn();

  String composed(WidgetTester tester) =>
      readProvider<ComposerController>(tester).text;

  /// A movement larger than the tap slop that provably stays inside [rect].
  /// Keys are ~120 px wide on the 1280×800 test viewport, so horizontal
  /// movement is the safe default; falls back to vertical for wide-but-short
  /// or narrow-but-tall surfaces.
  Offset slopMoveInside(Rect rect) {
    const distance = kTouchSlop + 4;
    const horizontal = Offset(distance, 0);
    if (rect.contains(rect.center + horizontal)) return horizontal;
    return const Offset(0, distance);
  }

  /// Presses down at the centre of [rect], drags by more than `kTouchSlop`
  /// while staying inside the key, then releases. Under the desired
  /// release-within-bounds semantics this must insert the key's character.
  Future<void> slopPress(WidgetTester tester, Rect rect) async {
    final move = slopMoveInside(rect);
    expect(
      move.distance,
      greaterThan(kTouchSlop),
      reason: 'precondition: the drag must exceed the tap slop '
          '(kTouchSlop = $kTouchSlop px) or the test proves nothing',
    );
    expect(
      rect.contains(rect.center + move),
      isTrue,
      reason: 'precondition: the pointer must stay INSIDE the key '
          '(rect $rect, release point ${rect.center + move}) — otherwise '
          'not inserting would be correct behaviour',
    );

    final gesture = await tester.startGesture(rect.center);
    await tester.pump();
    await gesture.moveBy(move);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('Key tap reliability', () {
    testWidgets('control: a clean tap inserts the letter', (tester) async {
      await pumpApp(tester);

      await tester.tap(keyboardText('q'));
      await tester.pumpAndSettle();

      expect(composed(tester), 'q');
    });

    testWidgets('press that slides within the key still inserts (THE BUG)',
        (tester) async {
      await pumpApp(tester);

      // Encodes release-within-bounds semantics: the finger drifts past
      // kTouchSlop but never leaves the key, so the letter must insert.
      // Today InkWell.onTap (TapGestureRecognizer) cancels at kTouchSlop —
      // the ripple plays but nothing is typed. This test documents and
      // reproduces that dropped-key bug; it stays RED until the fix lands.
      final rect = tester.getRect(keyMaterial('q'));
      await slopPress(tester, rect);

      expect(
        composed(tester),
        'q',
        reason: 'a press released inside the key bounds must insert the '
            'letter even after >kTouchSlop of movement',
      );
    });

    testWidgets('slide off the key and release elsewhere inserts nothing',
        (tester) async {
      await pumpApp(tester);

      final qRect = tester.getRect(keyMaterial('q'));
      final pRect = tester.getRect(keyMaterial('p'));
      expect(
        qRect.contains(pRect.center),
        isFalse,
        reason: 'precondition: the release point must be clearly outside q',
      );

      final gesture = await tester.startGesture(qRect.center);
      await tester.pump();
      await gesture.moveTo(pRect.center);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Neither the key pressed nor the key slid onto may insert.
      expect(
        composed(tester),
        '',
        reason: "sliding off 'q' and releasing over 'p' must insert "
            "nothing — not 'q' and not 'p'",
      );
    });

    testWidgets('fast typing rollover: second key down before first is up',
        (tester) async {
      await pumpApp(tester);

      final qCenter = tester.getRect(keyMaterial('q')).center;
      final wCenter = tester.getRect(keyMaterial('w')).center;

      final g1 = await tester.startGesture(qCenter, pointer: 1);
      await tester.pump();
      final g2 = await tester.startGesture(wCenter, pointer: 2);
      await tester.pump();
      await g1.up();
      await tester.pump();
      await g2.up();
      await tester.pumpAndSettle();

      expect(
        composed(tester),
        'qw',
        reason: 'overlapping presses on two keys must type both letters '
            'in press order',
      );
    });

    testWidgets('slop-tolerant press on the space key (THE BUG)',
        (tester) async {
      await pumpApp(tester);

      // A clean 'q' first, so the missing trailing space is unambiguous.
      await tester.tap(keyboardText('q'));
      await tester.pumpAndSettle();
      expect(composed(tester), 'q');

      // Same root cause as the letter-key test: InkWell.onTap on the space
      // bar cancels once the thumb drifts past kTouchSlop. RED until fixed.
      final rect = tester.getRect(keyMaterial(en.keySpace));
      await slopPress(tester, rect);

      expect(
        composed(tester),
        'q ',
        reason: 'a slop-y press released inside the space bar must still '
            'insert the space',
      );
    });
  });
}
