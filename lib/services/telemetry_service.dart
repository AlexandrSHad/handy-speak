import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Words from the tracked composer text shorter than this are not redacted
/// individually (the full text always is). The one named tunable: raise it
/// if verification shows diagnostics arriving over-redacted (ADDENDUM-06).
const int kRedactMinWordLength = 3;

/// Recent spoken utterances kept in the redaction ledger.
const int _utteranceRingSize = 5;

/// Recorded sink entries per list (canary-test seam, both modes).
const int _sinkCapacity = 20;

/// What a scope in [_suppressMessageScopes] ships instead of the raw
/// exception message.
const String _suppressedMessage = '[suppressed by scope policy]';

/// The sanitised shape of a reported failure. Plain Dart on purpose: every
/// privacy rule (ADR-0004) is testable without constructing SDK objects;
/// `sentry_flutter` types are touched only by the enabled-mode code below.
@immutable
class CapturedError {
  const CapturedError({
    required this.scope,
    required this.exceptionType,
    this.message,
    this.stackTrace,
    this.tags = const {},
    this.extras = const {},
  });

  /// Fixed call-site identifier (e.g. `tts/speak`) — never free text.
  final String scope;

  /// `runtimeType` of the error, e.g. `FormatException`.
  final String exceptionType;

  final String? message;

  final String? stackTrace;

  final Map<String, String> tags;

  final Map<String, Object?> extras;
}

/// The sanitised shape of a breadcrumb (ADR-0004: our code, fixed names,
/// allowlisted metadata only).
@immutable
class CapturedBreadcrumb {
  const CapturedBreadcrumb({required this.name, this.data = const {}});

  final String name;
  final Map<String, Object?> data;
}

/// Error telemetry for HandySpeak (ADDENDUM-06, ADR-0004).
///
/// Two modes, decided at compile time by [enabled] (a non-empty
/// `SENTRY_DSN` dart-define):
///
/// * **disabled** — the default for plain `puro flutter run`/`test`:
///   nothing can send anywhere. Captures land only in the in-memory sink
///   (the canary-test seam) and the error hooks still route framework /
///   platform errors through the same sanitisation.
/// * **enabled** — additionally forwards to Sentry, with the privacy
///   contract enforced in code: breadcrumbs only from our own allowlisted
///   names, tags/extras filtered by key, and child-authored text (current
///   composer content, recent utterances) replaced with `[redacted]`
///   everywhere it could appear — plus per-scope message suppression where
///   an exception's own message echoes stored content.
class TelemetryService {
  // ---- Compile-time config (const: a DSN change is a rebuild — accepted) ----

  static const String _dsn = String.fromEnvironment('SENTRY_DSN');
  static const String _rawEnvironment = String.fromEnvironment(
      'SENTRY_ENVIRONMENT', defaultValue: 'development');

  /// Telemetry is on only when a DSN was compiled in.
  bool get enabled => _dsn.isNotEmpty;

  /// Resolved Sentry environment. Allowlist-guarded: a typo'd define cannot
  /// silently create an unalerted fourth environment bucket.
  String get environment => resolveEnvironment(_rawEnvironment);

  @visibleForTesting
  static String resolveEnvironment(String raw) =>
      _allowedEnvironments.contains(raw) ? raw : 'development';

  static const Set<String> _allowedEnvironments = {
    'development',
    'preview',
    'production',
  };

  // ---- Allowlists (one place each — ADR-0004's code contract) ----

  /// Tag keys any event may carry; anything else is stripped.
  @visibleForTesting
  static const Set<String> tagKeyAllowlist = {
    'ui_locale',
    'main_lang',
    'second_lang',
    'tts_engine_available',
    'tts_status',
    'tts_error_code',
    'phrases_lang',
    'raw_length',
  };

  /// Breadcrumb names our code may emit; anything else is dropped outright.
  @visibleForTesting
  static const Set<String> breadcrumbNameAllowlist = {
    'app_start',
    'tts_status',
    'tts_language',
  };

  /// Scopes whose raw exception message must never ship — the exception
  /// text itself echoes stored content. They report exception type, a fixed
  /// description, and tags only.
  static const Set<String> _suppressMessageScopes = {'phrases/load_corrupt'};

  /// Every instrumented call site (ADDENDUM-06 §2–4). An unlisted scope is a
  /// coding slip: its event degrades to type + fixed description + tags
  /// rather than shipping an unreviewed message.
  static const Set<String> _scopeAllowlist = {
    'framework/render',
    'platform',
    'storage/init',
    'tts/init',
    'tts/set_language',
    'tts/voices',
    'tts/speak',
    'tts/stop',
    'phrases/load_corrupt',
  };

  // ---- Redaction ledger ----

  /// Current composer text (the *active* buffer — math-mode digits/symbols
  /// are not prose and are deliberately not tracked; spoken content stays
  /// covered by the utterance ring below).
  String? _secretText;

  final List<String> _utterances = [];

  /// Tracks [text] as the current composer content to redact from payloads.
  void registerSecret(String text) {
    _secretText = text.isEmpty ? null : text;
  }

  /// Tracks a spoken [text]; keeps the last [_utteranceRingSize].
  void registerUtterance(String text) {
    if (text.isEmpty) return;
    _utterances.add(text);
    while (_utterances.length > _utteranceRingSize) {
      _utterances.removeAt(0);
    }
  }

  @visibleForTesting
  List<String> collectSecrets() {
    final text = _secretText;
    if (text == null) return List.of(_utterances);
    return [
      text,
      ...text
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= kRedactMinWordLength),
      ..._utterances,
    ];
  }

  /// Replaces every secret occurrence with `[redacted]`. Matches are
  /// case-insensitive substrings (no word boundaries): over-redaction
  /// inside words is the accepted failure direction — a word-boundary match
  /// could miss concatenations, a case-sensitive one re-cased echoes.
  @visibleForTesting
  String redact(String input) {
    var output = input;
    final secrets = collectSecrets()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final secret in secrets) {
      if (secret.isEmpty) continue;
      output = output.replaceAll(
        RegExp(RegExp.escape(secret), caseSensitive: false),
        '[redacted]',
      );
    }
    return output;
  }

  // ---- Sanitisation (pure; shared by sink and Sentry sides) ----

  /// Applies the scope policy and redaction to [raw], and filters tags and
  /// extras to their key allowlists.
  @visibleForTesting
  CapturedError sanitizeError(CapturedError raw) {
    final messageSafe = _scopeAllowlist.contains(raw.scope) &&
        !_suppressMessageScopes.contains(raw.scope);
    return CapturedError(
      scope: raw.scope,
      exceptionType: redact(raw.exceptionType),
      message: messageSafe && raw.message != null
          ? redact(raw.message!)
          : (messageSafe ? null : _suppressedMessage),
      stackTrace: messageSafe && raw.stackTrace != null
          ? redact(raw.stackTrace!)
          : null,
      tags: _filterRedacted(raw.tags),
      extras: _filterRedactedExtras(raw.extras),
    );
  }

  /// Returns `null` when [raw]'s name is not allowlisted — the breadcrumb is
  /// dropped entirely, never recorded, never sent.
  @visibleForTesting
  CapturedBreadcrumb? sanitizeBreadcrumb(CapturedBreadcrumb raw) {
    if (!breadcrumbNameAllowlist.contains(raw.name)) return null;
    return CapturedBreadcrumb(
      name: raw.name,
      data: {
        for (final entry in raw.data.entries)
          entry.key:
              entry.value is String ? redact(entry.value as String) : entry.value,
      },
    );
  }

  Map<String, String> _filterRedacted(Map<String, String> raw) => {
        for (final entry in raw.entries)
          if (tagKeyAllowlist.contains(entry.key))
            entry.key: redact(entry.value),
      };

  Map<String, Object?> _filterRedactedExtras(Map<String, Object?> raw) => {
        for (final entry in raw.entries)
          if (tagKeyAllowlist.contains(entry.key))
            entry.key:
                entry.value is String ? redact(entry.value as String) : entry.value,
      };

  // ---- Sink (canary-test seam; records in BOTH modes, post-sanitisation) ----

  final List<CapturedError> _errorSink = [];
  final List<CapturedBreadcrumb> _breadcrumbSink = [];

  @visibleForTesting
  List<CapturedError> get capturedErrors => List.unmodifiable(_errorSink);

  @visibleForTesting
  List<CapturedBreadcrumb> get recordedBreadcrumbs =>
      List.unmodifiable(_breadcrumbSink);

  // ---- Public API ----

  /// Reports [error] under the fixed [scope]. The message is sanitised
  /// (scope policy + redaction) before anything records or sends.
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    required String scope,
    Map<String, String> tags = const {},
  }) async {
    final safe = sanitizeError(CapturedError(
      scope: scope,
      exceptionType: error.runtimeType.toString(),
      message: error.toString(),
      stackTrace: stackTrace?.toString(),
      tags: tags,
    ));
    _errorSink.add(safe);
    if (_errorSink.length > _sinkCapacity) _errorSink.removeAt(0);
    if (!enabled) return;

    try {
      if (_suppressMessageScopes.contains(scope)) {
        // Never hand the raw exception to the SDK: its message echoes stored
        // content. Fixed description + type + tags only (ADR-0004).
        // beforeSend re-checks the transaction as a backstop.
        await Sentry.captureEvent(SentryEvent(
          level: SentryLevel.error,
          transaction: safe.scope,
          tags: safe.tags.isEmpty ? null : Map<String, String>.of(safe.tags),
          exceptions: [
            SentryException(
              type: safe.exceptionType,
              value: _suppressedMessage,
            ),
          ],
        ));
      } else {
        // The SDK builds proper frames from the real throwable; beforeSend
        // redacts the resulting message before transport.
        await Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) {
            scope.transaction = safe.scope;
            for (final entry in safe.tags.entries) {
              scope.setTag(entry.key, entry.value);
            }
          },
        );
      }
    } catch (e) {
      // Telemetry must never take the app down with it.
      if (kDebugMode) debugPrint('telemetry: capture failed: $e');
    }
  }

  /// Records breadcrumb [name] with allowlisted [data]. Unknown names are
  /// dropped outright.
  void addBreadcrumb(String name, {Map<String, Object?> data = const {}}) {
    final safe = sanitizeBreadcrumb(CapturedBreadcrumb(name: name, data: data));
    if (safe == null) return;
    _breadcrumbSink.add(safe);
    if (_breadcrumbSink.length > _sinkCapacity) _breadcrumbSink.removeAt(0);
    if (!enabled) return;
    unawaited(Sentry.addBreadcrumb(Breadcrumb(
      message: safe.name,
      category: safe.name,
      data: {
        for (final entry in safe.data.entries)
          entry.key: entry.value?.toString() ?? '',
      },
    )));
  }

  // ---- Error hooks (both modes) ----

  /// Routes framework and platform errors into [captureError]. Render errors
  /// can embed `Text` widget contents — the child's message — so they flow
  /// through the same redaction. Both hooks chain to the handler they
  /// replace: `flutter_test` installs its own `FlutterError.onError` that
  /// must keep seeing errors, and in enabled mode Sentry's platform handler
  /// stays in the loop.
  void installErrorHooks() {
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(captureError(details.exception, details.stack,
          scope: 'framework/render'));
      previousFlutter?.call(details);
    };
    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(captureError(error, stackTrace, scope: 'platform'));
      return previousPlatform?.call(error, stackTrace) ?? false;
    };
  }

  // ---- Enabled-mode SDK wiring ----

  /// SDK configuration, called only from `SentryFlutter.init` when [enabled]
  /// (main.dart never calls it otherwise). No release (SDK auto-detects —
  /// verify format during the manual pass), no user, no navigator observer,
  /// no replay/screenshot/view-hierarchy (all default off, left off). ANR
  /// detection ships with the Android layer (`anrEnabled`, default on).
  /// App-start and slow/frozen-frame tracing come from
  /// `enableAutoPerformanceTracing` (default on) plus [tracesSampleRate].
  SentryFlutterOptions configure(SentryFlutterOptions options) {
    options
      ..dsn = _dsn
      ..environment = environment
      ..tracesSampleRate = environment == 'development' ? 1.0 : 0.1
      ..enableAutoSessionTracking = true
      ..enableUserInteractionBreadcrumbs =
          false // key-tap breadcrumbs would spell out the child's message
      ..enablePrintBreadcrumbs = false // print echoes utterances
      ..sendDefaultPii = false
      ..beforeSend = _beforeSend
      ..beforeBreadcrumb = _beforeBreadcrumb;
    return options;
  }

  /// Backstop redaction for events that reach the SDK without passing
  /// through [captureError] (e.g. the SDK's own zone handler): same
  /// transform, idempotent for our pre-sanitised events. Unknown-scope
  /// degradation is enforced at capture time; here the transaction only
  /// gates the suppressed-scope backstop. (Models are mutated in place —
  /// `copyWith` is deprecated in sentry 9.30.)
  SentryEvent? _beforeSend(SentryEvent event, Hint hint) {
    final suppress = event.transaction != null &&
        _suppressMessageScopes.contains(event.transaction);

    final message = event.message;
    if (message != null) {
      message.formatted =
          suppress ? _suppressedMessage : redact(message.formatted);
    }

    final exceptions = event.exceptions;
    if (exceptions != null) {
      for (final exception in exceptions) {
        if (suppress) {
          exception.value = _suppressedMessage;
        } else if (exception.value != null) {
          exception.value = redact(exception.value!);
        }
      }
    }

    final tags = event.tags;
    if (tags != null) {
      final allowed = _filterRedacted(tags);
      tags
        ..clear()
        ..addAll(allowed);
    }

    // `extra` is deprecated in favour of structured contexts; nothing we
    // ship populates it — strip it entirely rather than filter through
    // deprecated API.
    // ignore: deprecated_member_use
    event.extra?.clear();

    return event;
  }

  /// Drops any breadcrumb whose category is not allowlisted — including
  /// SDK/native-generated ones (the app allows only our three names).
  Breadcrumb? _beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    if (!breadcrumbNameAllowlist.contains(breadcrumb.category)) return null;
    final data = breadcrumb.data;
    if (data != null) {
      final redacted = <String, String>{
        for (final entry in data.entries) entry.key: redact(entry.value),
      };
      data
        ..clear()
        ..addAll(redacted);
    }
    return breadcrumb;
  }

  // ---- Disabled-mode hint ----

  /// One debug-console line when telemetry is off. Release builds never see
  /// it; called from `main()` in disabled mode only.
  void warnIfDisabled() {
    if (kDebugMode && !enabled) {
      debugPrint('handy_speak telemetry: SENTRY_DSN empty — copy '
          'dart_defines.example.json to dart_defines.json to enable.');
    }
  }
}
