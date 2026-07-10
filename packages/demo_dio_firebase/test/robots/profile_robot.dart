import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase-only profile robot (dio demo). Not part of the shared AC3 flow.
class ProfileRobot extends Robot {
  /// Creates a [ProfileRobot] driving [tester].
  ProfileRobot(super.tester);

  /// The seeded-name text key.
  static const name = Key('profile_name');

  /// The callable-trigger button key.
  static const callableButton = Key('create_order_callable_button');

  /// The callable-error text key.
  static const error = Key('profile_error');

  /// Waits for and asserts the seeded profile [value].
  Future<void> expectName(String value) async {
    await tester.pumpUntil(find.text(value));
    await tester.expectText(name, value);
  }

  /// Invokes the callable and waits for the error to render.
  Future<void> triggerCallable() async {
    await tester.tapButton(callableButton);
    await tester.pumpUntil(find.byKey(error));
  }

  /// Asserts the mapped callable-error [code] is displayed.
  Future<void> expectError(String code) => tester.expectText(error, code);
}
