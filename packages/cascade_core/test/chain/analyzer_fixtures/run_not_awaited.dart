import 'package:flutter/material.dart';

import 'demo_robot.dart';

/// Misuse shape (c): the terminal `.run()` future is never awaited.
///
/// `.run()` returns `Future<void>`; dropping it races the drain against the
/// rest of the test. `unawaited_futures` flags it in an async context.
Future<void> runNotAwaited(DemoRobot robot) async {
  robot.expectVisible(const Key('title')).run();
}
