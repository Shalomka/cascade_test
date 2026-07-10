import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC5 guard: Layer A (`cascade_core`) must not import any transport package.
///
/// The dependency graph already omits dio/http/firebase, so a stray import
/// would fail analysis; this test is a secondary belt that asserts the
/// source-level invariant directly and documents it.
///
/// Matching is by exact package name (parsed from the `package:<name>/` URI),
/// so `package:http_parser` is never mistaken for `package:http`. All four
/// adapter guards share this exact-name mechanism (S4).
void main() {
  // The full set of transport packages in this workspace. Each guard forbids
  // this set minus the transport(s) its own package legitimately owns.
  const forbidden = <String>{
    'dio',
    'http',
    'cloud_firestore',
    'cloud_functions',
    'firebase_core',
    'firebase_auth',
    'firebase_functions',
    'fake_cloud_firestore',
    'firebase_auth_mocks',
    'firebase_storage_mocks',
  };

  test('cascade_core lib imports no transport packages (AC5)', () {
    expect(forbiddenImportsIn('lib', forbidden), isEmpty);
  });
}

/// Returns `dir`'s Dart import/export lines whose `package:<name>/` matches one
/// of [forbidden] (exact package-name match), as `path: line` strings.
List<String> forbiddenImportsIn(String dir, Set<String> forbidden) {
  final packageRef = RegExp(
    r'''^\s*(?:import|export)\s+['"]package:([a-z0-9_]+)/''',
  );
  final offenders = <String>[];
  for (final entity in Directory(dir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final line in entity.readAsLinesSync()) {
      final name = packageRef.firstMatch(line)?.group(1);
      if (name != null && forbidden.contains(name)) {
        offenders.add('${entity.path}: ${line.trim()}');
      }
    }
  }
  return offenders;
}
