import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase-only profile robot (dio demo). Not part of the shared AC3 flow.
class ProfileRobot extends Robot<ProfileRobot> {
  /// Creates a [ProfileRobot] driving [tester].
  ProfileRobot(super.tester);

  /// The seeded-name text key.
  static const name = Key('profile_name');

  /// The callable-trigger button key.
  static const callableButton = Key('create_order_callable_button');

  /// The callable-error text key.
  static const error = Key('profile_error');

  /// Waits for and asserts the seeded profile [value].
  ///
  /// The wait matches by text (not key), so it uses a labeled [step] whose
  /// `find` runs at drain time rather than an unlabeled `tester.*` call.
  @useResult
  ProfileRobot expectName(String value) => step(
    'expectName($value)',
    () => tester.pumpUntil(find.text(value)),
  ).expectText(name, value);

  /// Invokes the callable and waits for the error to render.
  @useResult
  ProfileRobot triggerCallable() => tap(callableButton).pumpUntilVisible(error);

  /// Asserts the mapped callable-error [code] is displayed.
  @useResult
  ProfileRobot expectError(String code) => expectText(error, code);
}
