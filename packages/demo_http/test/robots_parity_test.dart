import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC3 machine proof: the shared-flow robots are byte-identical across the two
/// demos, so the http demo passes the same-shaped flow with zero robot change.
void main() {
  const sharedRobots = <String>[
    'login_robot.dart',
    'orders_robot.dart',
    'robots.dart',
  ];

  for (final name in sharedRobots) {
    test('$name is byte-identical across the two demos (AC3)', () {
      final httpFile = File('test/robots/$name');
      final dioFile = File('../demo_dio_firebase/test/robots/$name');

      expect(
        dioFile.existsSync(),
        isTrue,
        reason: 'Expected sibling robot at ${dioFile.path}',
      );
      expect(
        httpFile.readAsBytesSync(),
        dioFile.readAsBytesSync(),
        reason:
            '$name differs between the demos; the shared robots must be '
            'byte-identical.',
      );
    });
  }
}
