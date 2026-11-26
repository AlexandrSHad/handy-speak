import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Layering guard for the R1 C1 fix (`Phrase` moved to `lib/data/phrase.dart`,
// which broke the old `data ⇄ state` import cycle): nothing under `lib/data/`
// — recursively, so a future subdirectory cannot slip past the check — may
// import — or export — anything from `lib/state/`. Data sits below state,
// one-way, and the analyzer cannot warn about layering, so this test is the
// rule's enforcement (S02-issue-C1: a test, not a CI `grep -r "state/"
// lib/data/`, which isn't guaranteed on this repo's Windows dev machines
// and false-positives on comments).
//
// How the scan works (hardened over two PR #13 review rounds): comments are
// blanked first, string-aware (`blankComments` below), so a comment can
// neither *hide* a directive that follows it — the re-review's case — nor
// *smuggle* a fake directive into a fragment; only directive URIs are ever
// parsed, never free text. The cleaned source is then split on `;` into
// statements, not lines: a directive split across lines, a line packing
// several directives, either quote style, and every URI of a conditional
// import/export are all covered, and relative URIs resolve from the
// importing file's own directory. The parser is a pure function, so its
// edge cases are pinned by their own suite below. Headless-only by nature:
// it reads the repo from disk with `dart:io`, like `app_version_test.dart`.

// A directive *statement*: what sits between two `;` (or the file start) is
// one statement, however it is laid out. A statement that begins with the
// `import`/`export` keyword is a directive.
final directiveStart = RegExp(r'^(?:import|export)\b');

// A quoted URI, in either quote style — `allMatches` also catches the
// second URI of a conditional export in the same directive.
final quotedUri = RegExp(r'''['"]([^'"]+)['"]''');

/// Blanks `//` line-comment and `/* … */` block-comment content with spaces
/// (newlines kept), copying string literals verbatim so a `//` inside a
/// string — a URL in a phrase, say — is not mistaken for a comment. Assumes
/// simple literals: `lib/data` holds no triple-quoted or interpolated
/// strings; those would need a real lexer.
String blankComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (ch == '/' && next == '/') {
      // Line comment: blanked to the end of the line; the newline stays.
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
    } else if (ch == '/' && next == '*') {
      // Block comment: blanked to the closing `*/`, keeping newlines.
      out.write('  ');
      i += 2;
      while (i < source.length) {
        if (source[i] == '*' && i + 1 < source.length && source[i + 1] == '/') {
          out.write('  ');
          i += 2;
          break;
        }
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
    } else if (ch == "'" || ch == '"') {
      // String literal: copied verbatim, quote to quote, escapes kept.
      out.write(ch);
      i++;
      while (i < source.length && source[i] != ch) {
        if (source[i] == '\\' && i + 1 < source.length) {
          out.write(source[i]);
          out.write(source[i + 1]);
          i += 2;
        } else {
          out.write(source[i]);
          i++;
        }
      }
      if (i < source.length) {
        out.write(ch);
        i++;
      }
    } else {
      out.write(ch);
      i++;
    }
  }
  return out.toString();
}

/// The file's directory as a repo-root path ('/'-separated), so a relative
/// URI resolves from where the file actually lives — required because the
/// walk is recursive: `../../state/…` from `lib/data/sub/` points at
/// `lib/state/`, while the same URI from `lib/data/` does not.
String dirOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(0, normalized.lastIndexOf('/'));
}

/// Resolves a relative [uri] as seen from [fromDir] to a repo-root path
/// without package:path: split on `/`, drop `.` and empty segments, pop
/// on `..`.
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

bool resolvesIntoState(String dir, String uri) {
  if (uri.startsWith('package:handy_speak/state/')) return true;
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return false;
  return resolveFrom(dir, uri).startsWith('lib/state/');
}

/// The `lib/state` URIs that [source] — the content of the Dart file at
/// [path] — imports or exports. Empty when the file is clean.
List<String> stateUrisOf(String path, String source) {
  final dir = dirOf(path);
  final uris = <String>[];
  for (final statement in blankComments(source).split(';')) {
    if (!directiveStart.hasMatch(statement.trim())) continue;
    for (final match in quotedUri.allMatches(statement)) {
      final uri = match.group(1)!;
      if (resolvesIntoState(dir, uri)) uris.add(uri);
    }
  }
  return uris;
}

void main() {
  final dataDir = Directory('lib/data');

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

    test('no file in lib/data imports or exports anything from lib/state', () {
      final violations = <String>[];
      for (final file in dataDartFiles()) {
        for (final uri in stateUrisOf(file.path, file.readAsStringSync())) {
          violations.add('${file.path} → $uri');
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

  // The parser's own suite — every case below once fooled (or was meant to
  // fool) a previous version of the scan; they are the PR #13 review rounds
  // written down as tests.
  group('layering guard · parser (PR #13 review regressions)', () {
    test('a comment line before a directive does not hide it', () {
      const src = "import 'a.dart';\n// note\nimport '../state/x.dart';";
      expect(stateUrisOf('lib/data/x.dart', src), ['../state/x.dart']);
    });

    test('a file-opening header does not hide the first directive', () {
      const src = "// `Color` from `dart:ui`.\nimport '../state/x.dart';";
      expect(stateUrisOf('lib/data/x.dart', src), ['../state/x.dart']);
    });

    test('a block comment before a directive does not hide it', () {
      const src = "/* note */ import '../state/x.dart';";
      expect(stateUrisOf('lib/data/x.dart', src), ['../state/x.dart']);
    });

    test('a comment naming a state import cannot false-positive', () {
      const src = '// the old edge: phrases_data; '
          "import '../state/phrases_controller.dart' at its top\n"
          'const k = 1;';
      expect(stateUrisOf('lib/data/x.dart', src), isEmpty);
    });

    test("a '//' inside a string is not a comment and hides nothing", () {
      const src = "const s = 'https://x';\nimport '../state/x.dart';";
      expect(stateUrisOf('lib/data/x.dart', src), ['../state/x.dart']);
    });

    test('a directive split across lines is seen', () {
      const src = "import\n  '../state/x.dart';";
      expect(stateUrisOf('lib/data/x.dart', src), ['../state/x.dart']);
    });

    test('double-quoted URIs are seen', () {
      const src = 'import "../state/x.dart";';
      expect(stateUrisOf('lib/data/x.dart', src), ['../state/x.dart']);
    });

    test('several directives on one line are all seen', () {
      const src = "import 'a.dart'; import '../state/b.dart';";
      expect(stateUrisOf('lib/data/x.dart', src), ['../state/b.dart']);
    });

    test('every URI of a conditional export is seen', () {
      const src = "export '../state/a.dart'"
          " if (dart.library.io) '../state/b.dart';";
      expect(stateUrisOf('lib/data/x.dart', src),
          ['../state/a.dart', '../state/b.dart']);
    });

    test("relative URIs resolve from the file's own directory", () {
      const src = "import '../../state/deep.dart';";
      expect(
        stateUrisOf('lib/data/sub/x.dart', src),
        ['../../state/deep.dart'],
      );
      // The same URI from lib/data/ itself lands outside lib/state/.
      expect(stateUrisOf('lib/data/x.dart', src), isEmpty);
    });

    test('package-form state imports are seen', () {
      const src = "import 'package:handy_speak/state/x.dart';";
      expect(stateUrisOf('lib/data/x.dart', src),
          ['package:handy_speak/state/x.dart']);
    });
  });
}
