import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC5 guard: Layer A (`cascade_core`) must not import any transport package.
///
/// The dependency graph already omits dio/http/firebase, so a stray import
/// would fail analysis; this test asserts the source-level invariant directly
/// and documents it.
void main() {
  test('cascade_core lib imports no transport packages (AC5)', () {
    const forbidden = <String>[
      'package:dio',
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
          'Forbidden transport imports found in Layer A:\n'
          '${offenders.join('\n')}',
    );
  });
}
