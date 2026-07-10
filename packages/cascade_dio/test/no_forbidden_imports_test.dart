import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC5 guard: cascade_dio owns only the dio transport — its `lib/` must not
/// import package:http or any Firebase package.
void main() {
  test('cascade_dio lib imports no non-dio transport packages (AC5)', () {
    const forbidden = <String>[
      'package:http',
      'package:firebase',
      'package:cloud_firestore',
      'package:cloud_functions',
      'package:fake_cloud_firestore',
      'package:firebase_auth_mocks',
      'package:firebase_storage_mocks',
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
          'Forbidden transport imports found in cascade_dio:\n'
          '${offenders.join('\n')}',
    );
  });
}
