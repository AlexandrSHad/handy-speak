import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/services/telemetry_service.dart';

/// ADDENDUM-06 §6: the wrapper's privacy contract (ADR-0004). Compiled
/// without a DSN — telemetry is disabled by construction and only the
/// in-memory sink can observe anything (there is no DSN in this file, or
/// anywhere in test code).
void main() {
  group('TelemetryService', () {
    test('compiled without a DSN → disabled, sink still records', () async {
      final telemetry = TelemetryService();
      expect(telemetry.enabled, isFalse);

      await telemetry.captureError(
        StateError('boom'),
        StackTrace.current,
        scope: 'tts/speak',
        tags: const {'tts_status': 'unavailable'},
      );
      telemetry.addBreadcrumb('app_start');

      expect(telemetry.capturedErrors, hasLength(1));
      expect(telemetry.capturedErrors.single.scope, 'tts/speak');
      expect(telemetry.capturedErrors.single.tags['tts_status'],
          'unavailable');
      expect(telemetry.recordedBreadcrumbs, hasLength(1));
      expect(telemetry.recordedBreadcrumbs.single.name, 'app_start');
    });

    test('environment resolution', () {
      // Compiled without defines: the safe default.
      expect(TelemetryService().environment, 'development');
      expect(TelemetryService.resolveEnvironment('development'),
          'development');
      expect(TelemetryService.resolveEnvironment('preview'), 'preview');
      expect(TelemetryService.resolveEnvironment('production'), 'production');
      // A typo'd define cannot create an unalerted fourth bucket.
      expect(TelemetryService.resolveEnvironment('prodution'),
          'development');
      expect(TelemetryService.resolveEnvironment(''), 'development');
    });

    group('redaction transform', () {
      test('full composer text and its words ≥ 3 chars', () {
        final telemetry = TelemetryService()..registerSecret('my secret pass');
        expect(telemetry.redact('failed after my secret pass'),
            'failed after [redacted]');
        expect(telemetry.redact('the pass was here'), 'the [redacted] was here');
      });

      test('1–2-char words are not tracked individually', () {
        final telemetry = TelemetryService()..registerSecret('ab cd');
        // The full text is a secret; its short words are not.
        expect(telemetry.redact('x ab cd y'), 'x [redacted] y');
        expect(telemetry.redact('abcd'), 'abcd');
        expect(telemetry.redact('cd'), 'cd');
      });

      test('matching is case-insensitive', () {
        final telemetry = TelemetryService()..registerSecret('Hello');
        expect(telemetry.redact('said hello!'), 'said [redacted]!');
      });

      test('matching is substring — inside words too (over-redaction is the '
          'safe direction)', () {
        final telemetry = TelemetryService()..registerSecret('the quick');
        expect(telemetry.redact('there and quickly'),
            '[redacted]re and [redacted]ly');
      });

      test('utterance ring keeps the last 5, evicts older', () {
        final telemetry = TelemetryService();
        for (final utterance in [
          'utter one',
          'utter two',
          'utter three',
          'utter four',
          'utter five',
          'utter six',
        ]) {
          telemetry.registerUtterance(utterance);
        }
        expect(telemetry.redact('utter one'), 'utter one'); // evicted
        expect(telemetry.redact('utter six'), '[redacted]');
      });

      test('secret set = composer text + words ≥ 3 + utterances', () {
        final telemetry = TelemetryService()
          ..registerSecret('hi CANARYQQ7X')
          ..registerUtterance('spoken secret');
        expect(
          telemetry.collectSecrets(),
          containsAll(['hi CANARYQQ7X', 'CANARYQQ7X', 'spoken secret']),
        );
      });
    });

    group('captureError sanitisation', () {
      test('redacts the message and strips non-allowlisted tags', () async {
        final telemetry = TelemetryService()..registerSecret('CANARYQQ7X');
        await telemetry.captureError(
          Exception('boom while handling CANARYQQ7X'),
          null,
          scope: 'tts/speak',
          tags: const {'ui_locale': 'cs', 'stage': 'x'},
        );
        final captured = telemetry.capturedErrors.single;
        expect(captured.message, contains('[redacted]'));
        expect(captured.message?.contains('CANARYQQ7X'), isFalse);
        expect(captured.tags.keys, {'ui_locale'});
        expect(captured.tags['ui_locale'], 'cs');
      });

      test('sanitizeError strips non-allowlisted extras, keeps numbers, '
          'redacts string values', () {
        final telemetry = TelemetryService()..registerSecret('CANARYQQ7X');
        final safe = telemetry.sanitizeError(const CapturedError(
          scope: 'tts/speak',
          exceptionType: 'StateError',
          message: 'msg CANARYQQ7X',
          extras: {'raw_length': 7, 'note': 'has CANARYQQ7X'},
        ));
        expect(safe.extras.keys, {'raw_length'});
        expect(safe.extras['raw_length'], 7);
        expect(safe.extras.containsKey('note'), isFalse);
      });

      test('phrases/load_corrupt suppresses the raw message even when it '
          'echoes content (FormatException canary)', () async {
        final telemetry = TelemetryService();
        await telemetry.captureError(
          const FormatException('Unexpected character at CANARYQQ7X'),
          null,
          scope: 'phrases/load_corrupt',
          tags: const {'phrases_lang': 'en', 'raw_length': '42'},
        );
        final captured = telemetry.capturedErrors.single;
        expect(captured.message, '[suppressed by scope policy]');
        expect(captured.exceptionType, 'FormatException');
        expect(captured.stackTrace, isNull);
        expect(captured.tags['phrases_lang'], 'en');
        expect(captured.tags['raw_length'], '42');

        // Nothing anywhere in the payload spells the canary.
        final serialized = '${captured.message} ${captured.stackTrace} '
            '${captured.tags} ${captured.extras}';
        expect(serialized.contains('CANARYQQ7X'), isFalse);
      });

      test('unknown scope degrades to type + fixed description + tags',
          () async {
        final telemetry = TelemetryService();
        await telemetry.captureError(
          Exception('leaky CANARYQQ7X'),
          null,
          scope: 'brand/new',
          tags: const {'ui_locale': 'en'},
        );
        final captured = telemetry.capturedErrors.single;
        expect(captured.message, '[suppressed by scope policy]');
        expect(captured.exceptionType, '_Exception');
        expect(captured.stackTrace, isNull);
        expect(captured.tags['ui_locale'], 'en');
      });
    });

    group('breadcrumbs', () {
      test('non-allowlisted names are dropped entirely', () {
        final telemetry = TelemetryService()..registerSecret('CANARYQQ7X');
        telemetry.addBreadcrumb('navigation',
            data: const {'route': 'CANARYQQ7X'});
        expect(telemetry.recordedBreadcrumbs, isEmpty);
      });

      test('allowlisted names record with redacted data values', () {
        final telemetry = TelemetryService()..registerSecret('CANARYQQ7X');
        telemetry.addBreadcrumb('tts_status',
            data: const {'tts_status': 'ready', 'junk': 'CANARYQQ7X'});
        final crumb = telemetry.recordedBreadcrumbs.single;
        expect(crumb.data['tts_status'], 'ready');
        expect(crumb.data['junk'], '[redacted]');
      });
    });

    group('transactions (ADDENDUM-07)', () {
      test('unknown scope → born-finished no-op; rejection hits the sink', () {
        final telemetry = TelemetryService();
        final tx = telemetry.startTransaction('tts/typo');

        expect(tx.isFinished, isTrue);
        // A born-finished handle must tolerate any late caller mistake.
        tx.setTag('ui_locale', 'en');
        tx.child('stop');
        tx.finish(tags: const {'tts_status': 'ready'});

        expect(telemetry.recordedTransactions, hasLength(1));
        final captured = telemetry.recordedTransactions.single;
        expect(captured.scope, 'tts/typo');
        expect(captured.rejected, isTrue);
        expect(captured.tags, isEmpty);
        expect(captured.childNames, isEmpty);
      });

      test('tags are filtered at creation, at setTag and at finish; child '
          'names record in order', () {
        final telemetry = TelemetryService();
        final tx = telemetry.startTransaction('tts/speak', tags: const {
          'ui_locale': 'cs-CZ',
          'raw_length': '12',
          'evil': 'nope',
        });
        expect(tx.isFinished, isFalse);

        tx.setTag('speak_outcome', 'spoken');
        tx.setTag('another_evil', 'nope');
        tx.child('stop');
        tx.child('submit');
        tx.finish(tags: const {'also_evil': 'nope'});

        expect(telemetry.recordedTransactions, hasLength(1));
        final captured = telemetry.recordedTransactions.single;
        expect(captured.rejected, isFalse);
        expect(captured.scope, 'tts/speak');
        expect(captured.tags.keys, {'ui_locale', 'raw_length', 'speak_outcome'});
        expect(captured.tags['speak_outcome'], 'spoken');
        expect(captured.childNames, ['stop', 'submit']);
      });

      test('tag values are redacted like error tags (canary in a value)', () {
        final telemetry = TelemetryService()..registerSecret('CANARYQQ7X');
        final tx = telemetry.startTransaction('tts/speak');
        tx.setTag('ui_locale', 'x-CANARYQQ7X');
        tx.finish();

        final serialized =
            '${telemetry.recordedTransactions.single.scope} '
            '${telemetry.recordedTransactions.single.tags} '
            '${telemetry.recordedTransactions.single.childNames}';
        expect(serialized.contains('CANARYQQ7X'), isFalse);
        expect(serialized, contains('[redacted]'));
      });

      test('double finish is ignored — the first outcome stands', () {
        final telemetry = TelemetryService();
        final tx = telemetry.startTransaction('tts/ready');
        tx.finish(tags: const {'tts_status': 'ready'});
        tx.finish(tags: const {'tts_status': 'unavailable'});

        expect(telemetry.recordedTransactions, hasLength(1));
        expect(telemetry.recordedTransactions.single.tags['tts_status'],
            'ready');
      });

      test('sink keeps only the last 20 transactions', () {
        final telemetry = TelemetryService();
        for (var i = 0; i < 25; i++) {
          telemetry.startTransaction('tts/ready').finish();
        }
        expect(telemetry.recordedTransactions, hasLength(20));
      });
    });

    test('sink keeps only the last 20 entries', () async {
      final telemetry = TelemetryService();
      for (var i = 0; i < 25; i++) {
        await telemetry.captureError(
            StateError('e$i'), null, scope: 'tts/speak');
      }
      expect(telemetry.capturedErrors, hasLength(20));
      expect(telemetry.capturedErrors.first.message, contains('e5'));
      expect(telemetry.capturedErrors.last.message, contains('e24'));
    });
  });
}
