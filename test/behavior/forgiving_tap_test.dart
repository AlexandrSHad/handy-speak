import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';

import '../support/app_harness.dart';

/// Forgiving-tap / accessibility feature suite, seeded from the retired keytap
/// tests during the testing-prep stage. Pins the `ForgivingTap`
/// release-within-bounds contract (see `docs/forgiving-taps.md`): a press
/// released inside a key inserts the letter no matter how far the finger
/// drifted, while a press released off the key inserts nothing.

final _en = AppLocalizationsEn();

String composed(WidgetTester tester) =>
    readProvider<ComposerController>(tester).text;

/// A [Text] scoped to the keyboard.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );

/// The tappable key surface ([Material]) behind a key label.
Finder keyMaterial(String label) => find
    .ancestor(of: keyboardText(label), matching: find.byType(Material))
    .first;

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
/// while staying inside the key, then releases. Under the release-within-bounds
/// semantics this must insert the key's character.
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

void main() {
  group('Forgiving tap', () {
    testWidgets('control: a clean tap inserts the letter', (tester) async {
      await pumpApp(tester);

      await tester.tap(keyboardText('q'));
      await tester.pumpAndSettle();

      expect(composed(tester), 'q');
    });

    testWidgets('press that slides within the key still inserts',
        (tester) async {
      await pumpApp(tester);

      // Release-within-bounds semantics: the finger drifts past kTouchSlop but
      // never leaves the key, so the letter must insert.
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

    testWidgets('slop-tolerant press on the space key inserts the space',
        (tester) async {
      await pumpApp(tester);

      // A clean 'q' first, so the trailing space is unambiguous.
      await tester.tap(keyboardText('q'));
      await tester.pumpAndSettle();
      expect(composed(tester), 'q');

      final rect = tester.getRect(keyMaterial(_en.keySpace));
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
