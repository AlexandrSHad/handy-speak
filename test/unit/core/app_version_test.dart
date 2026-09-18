import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_version.dart';

// Pins `kAppVersion` to `pubspec.yaml`'s `version:` field (build suffix
// stripped). The constant is hand-maintained — this is what stops it drifting
// from the pubspec after a version bump.
//
// Headless-only by nature: it reads the repo from disk with `dart:io`, which
// an on-device `integration_test` run cannot do. So it is a standalone
// `test/*_test.dart`, not half of a suite pair.

void main() {
  test('kAppVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'no `version:` field in pubspec.yaml');

    // `0.6.0+1` → `0.6.0`: the marketing version is what the UI shows.
    final pubspecVersion = match!.group(1)!.split('+').first;
    expect(kAppVersion, pubspecVersion);
  });
}
