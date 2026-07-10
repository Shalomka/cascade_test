import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC5 guard: cascade_firebase owns only the Firebase transport — its `lib/`
/// must not import dio or package:http.
void main() {
  test('cascade_firebase lib imports no HTTP transport packages (AC5)', () {
    const forbidden = <String>[
      'package:dio',
      'package:http/',
      "package:http'",
    ];

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in entity.readAsLinesSync()) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('import') && !trimmed.startsWith('export')) {
          continue;
        }
        for (final needle in forbidden) {
          if (trimmed.contains(needle)) {
            offenders.add('${entity.path}: $trimmed');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Forbidden transport imports found in cascade_firebase:\n'
          '${offenders.join('\n')}',
    );
  });
}
