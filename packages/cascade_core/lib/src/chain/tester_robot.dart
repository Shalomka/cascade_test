import 'package:cascade_core/src/robot/robot.dart';
import 'package:cascade_core/src/tester/widget_tester_x.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// A [Robot] that adds the low-level [WidgetTesterX] verbs the base does not
/// already expose — input focus/content, button state, pin entry, and keyboard
/// submit (C2).
///
/// It shares the base's single verb vocabulary ([tap], [enterText],
/// [expectVisible], [expectText], [pumpUntilVisible], …) and layers on the
/// remaining tester primitives, so a demo's raw-tester step (e.g. "policies")
/// joins the same lazy chain engine instead of interleaving eager `tester.*`
/// calls with a lazy chain. Each verb enqueues one labeled step whose thunk
/// calls the unchanged [WidgetTesterX] primitive; the extension itself is not
/// modified and remains the imperative escape hatch (G7).
class TesterRobot extends Robot<TesterRobot> {
  /// Creates a [TesterRobot] driving [tester].
  TesterRobot(super.tester);

  /// Enters [text] into the [EditableText] (e.g. Pinput) at or under [key].
  @useResult
  TesterRobot enterPin(Key key, String text) =>
      step('enterPin($key)', () => tester.enterPinByKey(key, text));

  /// Submits the focused text input via the keyboard 'done' action.
  @useResult
  TesterRobot submitText() => step('submitText()', tester.submitText);

  /// Asserts the [TextField] at or under [key] currently holds [text].
  @useResult
  TesterRobot expectInputHasText(Key key, String text) => step(
    'expectInputHasText($key)',
    () => tester.expectInputHasText(key, text),
  );

  /// Asserts the [TextField] at or under [key] has focus.
  @useResult
  TesterRobot expectInputHasFocus(Key key) => step(
    'expectInputHasFocus($key)',
    () => tester.expectInputHasFocus(key),
  );

  /// Asserts the button with [key] is enabled.
  @useResult
  TesterRobot expectButtonEnabled(Key key) => step(
    'expectButtonEnabled($key)',
    () => tester.expectButtonEnabled(key),
  );

  /// Asserts the button with [key] is disabled.
  @useResult
  TesterRobot expectButtonDisabled(Key key) => step(
    'expectButtonDisabled($key)',
    () => tester.expectButtonDisabled(key),
  );
}
