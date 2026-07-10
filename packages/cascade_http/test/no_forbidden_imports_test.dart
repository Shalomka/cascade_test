import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC5 guard: cascade_http owns only the package:http transport — its `lib/`
/// must not import dio or any Firebase package.
void main() {
  test('cascade_http lib imports no non-http transport packages (AC5)', () {
    const forbidden = <String>[
      'package:dio',
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
          'Forbidden transport imports found in cascade_http:\n'
          '${offenders.join('\n')}',
    );
  });
}
