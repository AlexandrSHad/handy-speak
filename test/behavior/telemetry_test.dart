import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/services/telemetry_service.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';

import '../support/app_harness.dart';

/// Telemetry canaries (ADDENDUM-06; ADR-0004's "a canary test fails the
/// build" clause). The harness boots with a DISABLED TelemetryService (no
/// DSN is ever compiled into tests — there is no DSN in this file) and
/// exposes it on TestApp. Each test drives a real failure path carrying a
/// canary and asserts the canary reaches NO recorded payload: error
/// message, stack trace, tags, extras, breadcrumbs — serialized and
/// searched case-insensitively.
void main() {
  final en = AppLocalizationsEn();

  // Lowercase because the keyboard stores typed text lowercase; the leak
  // search lowercases everything so either case of a leak is caught.
  const canary = 'canaryqq7x';

  String allPayloads(TelemetryService telemetry) {
    final buffer = StringBuffer();
    for (final error in telemetry.capturedErrors) {
      buffer
        ..write(error.scope)
        ..write(error.exceptionType)
        ..write(error.message)
        ..write(error.stackTrace)
        ..write(error.tags)
        ..write(error.extras);
    }
    for (final crumb in telemetry.recordedBreadcrumbs) {
      buffer
        ..write(crumb.name)
        ..write(crumb.data);
    }
    for (final tx in telemetry.recordedTransactions) {
      buffer
        ..write(tx.scope)
        ..write(tx.tags)
        ..write(tx.childNames)
        ..write(tx.rejected);
    }
    return buffer.toString();
  }

  // Same key finder as the other behaviour suites (per-file copies are the
  // convention here).
  Finder keyboardText(String label) => find.descendant(
        of: find.byType(KeyboardView),
        matching: find.text(label),
      );

  Future<void> typeCanary(WidgetTester tester) async {
    for (final ch in canary.split('')) {
      await tester.tap(keyboardText(ch));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a TTS speak failure ships the canary redacted', (tester) async {
    final app = await pumpApp(tester);
    await typeCanary(tester);

    app.tts.speakErrorMessage = 'engine refused CANARYQQ7X';
    await tester.tap(find.text(en.speak));
    await tester.pumpAndSettle();

    expect(
      app.telemetry.capturedErrors.map((e) => e.scope).toList(),
      contains('tts/speak'),
    );
    expect(allPayloads(app.telemetry).toLowerCase(), isNot(contains(canary)));
    expect(allPayloads(app.telemetry), contains('[redacted]'));
  });

  testWidgets('a real framework error ships redacted (render trees embed '
      'Text contents)', (tester) async {
    final app = await pumpApp(tester);
    await typeCanary(tester);

    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('layout failed near CANARYQQ7X'),
      stack: StackTrace.current,
      context: ErrorDescription('rendering Text CANARYQQ7X'),
    ));
    // The chained base handler (flutter_test's) records the error for the
    // test — drain it so the test stays green; our capture already ran.
    expect(tester.takeException(), isNotNull);

    final frameworkCaptures = app.telemetry.capturedErrors
        .where((e) => e.scope == 'framework/render')
        .toList();
    expect(frameworkCaptures, isNotEmpty);
    expect(allPayloads(app.telemetry).toLowerCase(), isNot(contains(canary)));
  });

  testWidgets('corrupt stored phrases capture without the stored content',
      (tester) async {
    final app = await pumpApp(tester,
        prefs: {'phrases_en': 'this is not json {{{ CANARYQQ7X'});

    final captures = app.telemetry.capturedErrors
        .where((e) => e.scope == 'phrases/load_corrupt')
        .toList();
    expect(captures, hasLength(1));
    expect(captures.single.message, '[suppressed by scope policy]');
    expect(allPayloads(app.telemetry).toLowerCase(), isNot(contains(canary)));
  });

  testWidgets('a healthy boot emits only allowlisted breadcrumbs and no '
      'errors', (tester) async {
    final app = await pumpApp(tester);

    expect(app.telemetry.capturedErrors, isEmpty);
    final names = app.telemetry.recordedBreadcrumbs.map((b) => b.name).toSet();
    expect(names, containsAll(['app_start', 'tts_status']));
    for (final crumb in app.telemetry.recordedBreadcrumbs) {
      expect(
        TelemetryService.breadcrumbNameAllowlist.contains(crumb.name),
        isTrue,
        reason: 'unexpected breadcrumb name: ${crumb.name}',
      );
    }
  });

  testWidgets('a healthy boot finishes tts/ready with tts_status=ready '
      '(ADDENDUM-07)', (tester) async {
    final app = await pumpApp(tester);

    final ready = app.telemetry.recordedTransactions
        .where((t) => t.scope == 'tts/ready')
        .toList();
    expect(ready, hasLength(1));
    expect(ready.single.rejected, isFalse);
    expect(ready.single.tags['tts_status'], 'ready');
    expect(allPayloads(app.telemetry).toLowerCase(), isNot(contains(canary)));
  });

  testWidgets('an engine that fails to bind finishes tts/ready with '
      'tts_status=unavailable (ADDENDUM-07)', (tester) async {
    final app = await pumpApp(tester, ttsInitErrorMessage: 'bind boom');

    final ready = app.telemetry.recordedTransactions
        .where((t) => t.scope == 'tts/ready')
        .toList();
    expect(ready, hasLength(1));
    expect(ready.single.tags['tts_status'], 'unavailable');
  });

  testWidgets('a Speak tap produces a spoken tts/speak transaction without '
      'the canary (ADDENDUM-07)', (tester) async {
    final app = await pumpApp(tester);
    await typeCanary(tester);

    await tester.tap(find.text(en.speak));
    await tester.pumpAndSettle();
    // The fake raises the platform's onStart/onDone pair by itself, like a
    // real engine — first sound is what finishes the transaction.

    final spoken = app.telemetry.recordedTransactions
        .where((t) => t.scope == 'tts/speak')
        .toList();
    expect(spoken, hasLength(1));
    expect(spoken.single.rejected, isFalse);
    expect(spoken.single.tags['speak_outcome'], 'spoken');
    expect(spoken.single.tags['raw_length'], canary.length.toString());
    expect(spoken.single.childNames, containsAll(['stop', 'submit']));
    expect(allPayloads(app.telemetry).toLowerCase(), isNot(contains(canary)));
  });

  testWidgets('a speak that never starts is superseded by the next tap '
      'and stays canary-free (ADDENDUM-07)', (tester) async {
    final app = await pumpApp(tester)
      ..tts.autoEmitPlaybackEvents = false; // engine reports nothing
    await typeCanary(tester);

    // No start event ever: the first tap's transaction stays open — until
    // the second tap supersedes it.
    await tester.tap(find.text(en.speak));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.speak));
    await tester.pumpAndSettle();

    // Now playback begins — for the newest utterance only.
    await app.tts.emitStart();
    await tester.pump();

    final outcomes = app.telemetry.recordedTransactions
        .where((t) => t.scope == 'tts/speak')
        .map((t) => t.tags['speak_outcome'])
        .toList();
    expect(outcomes, ['superseded', 'spoken']);
    expect(allPayloads(app.telemetry).toLowerCase(), isNot(contains(canary)));
  });
}
