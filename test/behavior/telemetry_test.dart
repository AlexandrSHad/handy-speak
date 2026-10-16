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
}
