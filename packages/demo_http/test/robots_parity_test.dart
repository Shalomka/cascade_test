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

  // Resolve the workspace `packages/` dir by walking up from the current
  // directory, rather than assuming the CWD is the demo_http package root.
  // This keeps the test correct regardless of where the runner is invoked (S5).
  final packagesDir = _packagesRoot();

  for (final name in sharedRobots) {
    test('$name is byte-identical across the two demos (AC3)', () {
      final httpFile = File('${packagesDir.path}/demo_http/test/robots/$name');
      final dioFile = File(
        '${packagesDir.path}/demo_dio_firebase/test/robots/$name',
      );

      expect(
        httpFile.existsSync(),
        isTrue,
        reason: 'Expected robot at ${httpFile.path}',
      );
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

/// Walks up from [Directory.current] to the workspace `packages/` directory
/// (the one containing both demo packages), so path resolution does not depend
/// on the process working directory.
Directory _packagesRoot() {
  for (var dir = Directory.current.absolute; ; dir = dir.parent) {
    final packages = Directory('${dir.path}/packages');
    if (Directory('${packages.path}/demo_http').existsSync() &&
        Directory('${packages.path}/demo_dio_firebase').existsSync()) {
      return packages;
    }
    if (dir.parent.path == dir.path) {
      throw StateError(
        'Could not locate the workspace packages/ dir from '
        '${Directory.current.absolute.path}',
      );
    }
  }
}
