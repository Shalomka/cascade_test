import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC5 guard: cascade_firebase owns only the Firebase transport — its `lib/`
/// must not import dio or package:http.
///
/// Matching is by exact package name (parsed from the `package:<name>/` URI),
/// so `package:http_parser` is never mistaken for `package:http`. All four
/// adapter guards share this exact-name mechanism (S4).
void main() {
  // Full workspace transport set minus the Firebase family this package owns.
  const forbidden = <String>{'dio', 'http'};

  test('cascade_firebase lib imports no HTTP transport packages (AC5)', () {
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
