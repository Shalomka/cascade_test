import 'package:flutter/material.dart';

import 'demo_robot.dart';

/// Misuse shape (a): a chain is built but never `.run()`.
///
/// Every verb is `@useResult`, so discarding the returned robot is flagged as
/// `unused_result` — the chain would silently never execute.
void chainNeverRun(DemoRobot robot) {
  robot.expectVisible(const Key('title')).tap(const Key('cta'));
}
