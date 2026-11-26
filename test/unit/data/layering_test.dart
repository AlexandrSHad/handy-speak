import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Layering guard for the R1 C1 fix (`Phrase` moved to `lib/data/phrase.dart`,
// which broke the old `data ⇄ state` import cycle): nothing under `lib/data/`
// — recursively, so a future subdirectory cannot slip past the check — may
// import — or export — anything from `lib/state/`. Data sits below state,
// one-way, and the analyzer cannot warn about layering, so this test is the
// rule's enforcement (S02-issue-C1: a test, not a CI `grep -r "state/"
// lib/data/`, which is not guaranteed on this repo's Windows dev machines
// and false-positives on comments).
//
// It parses import/export *directive URIs only*, never free text, so a
// comment that merely mentions `state/` cannot trip it. The directive scan
// is deliberately wider than line-at-a-time matching (hardened after the
// PR #13 review): it covers single- *and* double-quoted URIs, directives
// split across lines (`import\n  '…';`), several URIs in one directive
// (conditional import/export), and several directives on one line.
// Headless-only by nature: it reads the repo from disk with `dart:io`,
// like `app_version_test.dart`.

void main() {
  final dataDir = Directory('lib/data');

  // A directive *fragment*: what sits between two `;` (or the file start)
  // is one statement, however it is laid out. A fragment that begins with
  // the `import`/`export` keyword is a directive; a comment line can never
  // begin one (`//`, `///`, `*` all sit before the keyword), which is what
  // keeps the comment-mention guarantee above.
  final directiveStart = RegExp(r'^(?:import|export)\b');
  // A quoted URI, in either quote style — `allMatches` also catches the
  // second URI of a conditional export in the same directive.
  final quotedUri = RegExp(r'''['"]([^'"]+)['"]''');

  // The file's directory as a repo-root path ('/'-separated), so a relative
  // URI resolves from where the file actually lives — required now that the
  // walk is recursive: `../../state/…` from `lib/data/sub/` points at
  // `lib/state/`, while the same URI from `lib/data/` does not.
  String dirOf(File f) {
    final normalized = f.path.replaceAll('\\', '/');
    return normalized.substring(0, normalized.lastIndexOf('/'));
  }

  // Resolves a relative [uri] as seen from [fromDir] to a repo-root path
  // without package:path: split on `/`, drop `.` and empty segments,
  // pop on `..`.
  String resolveFrom(String fromDir, String uri) {
    final out = <String>[];
    for (final seg in [...fromDir.split('/'), ...uri.split('/')]) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else {
        out.add(seg);
      }
    }
    return out.join('/');
  }

  bool resolvesIntoState(File file, String uri) {
    if (uri.startsWith('package:handy_speak/state/')) return true;
    if (uri.startsWith('package:') || uri.startsWith('dart:')) return false;
    return resolveFrom(dirOf(file), uri).startsWith('lib/state/');
  }

  Iterable<File> dataDartFiles() => dataDir
      .listSync(recursive: true)
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
        // Statements, not lines: splitting on `;` keeps a directive whole
        // even when it spans lines, and still yields every directive of a
        // line that packs several.
        for (final fragment in file.readAsStringSync().split(';')) {
          if (!directiveStart.hasMatch(fragment.trim())) continue;
          for (final match in quotedUri.allMatches(fragment)) {
            final uri = match.group(1)!;
            if (resolvesIntoState(file, uri)) {
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
