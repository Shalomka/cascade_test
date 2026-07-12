import 'package:flutter/material.dart';

import 'demo_robot.dart';

/// Misuse shape (b): the muscle-memory `await robot.verb();` reflex.
///
/// A verb returns the robot (not a `Future`), so awaiting it is a no-op that
/// would silently pass. `await_only_futures` flags the `await` on a non-future.
Future<void> awaitVerbNoOp(DemoRobot robot) async {
  await robot.expectVisible(const Key('title'));
}
