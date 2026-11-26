import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Layering guard for the R1 C1 fix (`Phrase` moved to `lib/data/phrase.dart`,
// which broke the old `data ⇄ state` import cycle): nothing under `lib/data/`
// may import — or export — anything from `lib/state/`. Data sits below state,
// one-way, and the analyzer cannot warn about layering, so this test is the
// rule's enforcement (S02-issue-C1: a test, not a CI `grep -r "state/"
// lib/data/`, which is not guaranteed on this repo's Windows dev machines
// and false-positives on comments).
//
// It parses import/export *directive URIs only*, never free text, so a
// comment that merely mentions `state/` cannot trip it. Headless-only by
// nature: it reads the repo from disk with `dart:io`, like
// `app_version_test.dart`.

void main() {
  final dataDir = Directory('lib/data');

  // A directive line (after trim): `import`/`export` keyword, then the URI(s).
  final directiveStart = RegExp(r'^(?:import|export)\b');
  // Single-quoted URIs — the repo's uniform import style. `allMatches` also
  // catches the second URI of a conditional export on the same line.
  final quotedUri = RegExp(r"'([^']+)'");

  // Resolves a relative [uri] as seen from `lib/data` to a repo-root path
  // without package:path: split on `/` and `\`, drop `.` and empty
  // segments, pop on `..`.
  String resolveFromDataDir(String uri) {
    final out = <String>[];
    for (final seg in [...'lib/data'.split('/'), ...uri.split('/')]) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else {
        out.add(seg);
      }
    }
    return out.join('/');
  }

  bool resolvesIntoState(String uri) {
    if (uri.startsWith('package:handy_speak/state/')) return true;
    if (uri.startsWith('package:') || uri.startsWith('dart:')) return false;
    return resolveFromDataDir(uri).startsWith('lib/state/');
  }

  Iterable<File> dataDartFiles() => dataDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  group('layering · lib/data', () {
    test('the guard sees the data layer — it is not vacuously green', () {
      expect(dataDir.existsSync(), isTrue,
          reason: 'expected to run from the repo root via puro flutter test');
      expect(dataDartFiles(), isNotEmpty);
    });

    test('no file in lib/data imports or exports anything from lib/state',
        () {
      final violations = <String>[];
      for (final file in dataDartFiles()) {
        for (final line in file.readAsLinesSync()) {
          final trimmed = line.trim();
          if (!directiveStart.hasMatch(trimmed)) continue;
          for (final match in quotedUri.allMatches(trimmed)) {
            final uri = match.group(1)!;
            if (resolvesIntoState(uri)) {
              violations.add('${file.path} → $uri');
            }
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'lib/data must never depend on lib/state '
            '(CLAUDE.md layout convention, R1 C1)',
      );
    });
  });
}
