import 'package:cascade_core/src/tester/widget_tester_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Base class for BDD robots (R5.1).
///
/// A robot wraps a [WidgetTester] and exposes intention-revealing, key-driven
/// verbs so tests read Given/When/Then with no raw `find.byType`/`tester.tap`
/// (R5.2). Per-app robots extend this and compose these primitives into
/// domain flows. Conditional steps should be explicit `...IfPresent` verbs
/// (R5.3) — [tapIfPresent] is the canonical example.
abstract class Robot {
  /// Creates a robot bound to [tester].
  Robot(this.tester);

  /// The tester this robot drives.
  final WidgetTester tester;

  /// Asserts the widget with [key] is visible.
  Future<void> expectVisible(Key key) => tester.expectWidget(key);

  /// Asserts the widget with [key] is not present.
  Future<void> expectNotVisible(Key key) => tester.expectNoWidget(key);

  /// Asserts the widget with [key] displays [text].
  Future<void> expectText(Key key, String text) => tester.expectText(key, text);

  /// Taps the widget with [key].
  Future<void> tap(Key key) => tester.tapButton(key);

  /// Enters [text] into the field under [key].
  Future<void> enterText(Key key, String text) =>
      tester.enterTextByKey(key, text);

  /// Waits until the widget with [key] appears (deterministic; never settle).
  Future<void> pumpUntilVisible(
    Key key, {
    Duration timeout = const Duration(seconds: 10),
  }) => tester.pumpUntil(find.byKey(key), timeout: timeout);

  /// Taps the widget with [key] only if it is currently present (R5.3).
  Future<void> tapIfPresent(Key key) async {
    if (find.byKey(key).evaluate().isNotEmpty) {
      await tester.tapButton(key);
    }
  }
}
