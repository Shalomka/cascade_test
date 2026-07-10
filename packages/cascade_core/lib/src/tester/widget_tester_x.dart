// Debug helpers deliberately print to the console (R7.3).
// ignore_for_file: avoid_print

import 'package:cascade_core/src/builder/harness_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// App-agnostic [WidgetTester] verbs for driving a full-system test by [Key]
/// (R4.3). Ported from the Teroxx prior art and decoupled from app types:
/// custom button/text widgets are resolved through [HarnessConfig] (R4.4).
///
/// These verbs never call `pumpAndSettle` (real apps have repeating timers);
/// use [pumpUntil] to wait deterministically.
extension WidgetTesterX on WidgetTester {
  /// Pumps twice through animations of [duration] (drains transient frames).
  Future<WidgetTester> pumpThroughAnimations([
    Duration duration = const Duration(seconds: 10),
  ]) async {
    await pump(duration);
    await pump(duration);
    return this;
  }

  /// Pumps in [step] increments until [finder] matches or [timeout] elapses.
  ///
  /// The sanctioned replacement for the prior art's manual fixed-iteration
  /// `pump()` loops. Deterministic (count-based) and never `pumpAndSettle`.
  Future<void> pumpUntil(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final maxIterations = (timeout.inMilliseconds / step.inMilliseconds).ceil();
    for (var i = 0; i < maxIterations; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await pump(step);
    }
    if (finder.evaluate().isNotEmpty) return;
    fail(
      'pumpUntil timed out after ${timeout.inMilliseconds}ms waiting for: '
      '${finder.describeMatch(Plurality.zero)}',
    );
  }

  /// Asserts a widget with [key] is present.
  Future<WidgetTester> expectWidget(Key key) async {
    expect(find.byKey(key), findsOneWidget);
    return this;
  }

  /// Asserts a widget with [key] is absent.
  Future<WidgetTester> expectNoWidget(Key key) async {
    expect(find.byKey(key), findsNothing);
    return this;
  }

  /// Asserts the widget with [key] displays [text].
  ///
  /// Consults [HarnessConfig.textExtractors] first, then the keyed widget
  /// itself, then descendant [Text] widgets, then [RichText] spans.
  Future<WidgetTester> expectText(Key key, String text) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    final target = widget(finder);

    for (final extractor in activeHarnessConfig.textExtractors) {
      final extracted = extractor(target);
      if (extracted != null) {
        expect(extracted, text);
        return this;
      }
    }

    if (target is Text) {
      expect(target.data, text);
      return this;
    }

    final textFinder = find.descendant(of: finder, matching: find.byType(Text));
    if (textFinder.evaluate().isNotEmpty) {
      final texts = textFinder
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .toList();
      expect(texts, contains(text));
      return this;
    }

    final targetIsRich = target is RichText;
    final richFinder = targetIsRich
        ? finder
        : find.descendant(of: finder, matching: find.byType(RichText));
    if (richFinder.evaluate().isNotEmpty) {
      final texts = richFinder
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText())
          .toList();
      expect(texts, contains(text));
      return this;
    }

    fail('No Text or RichText descendants for widget with key $key');
  }

  /// Taps the widget with [key] and pumps through animations.
  Future<WidgetTester> tapButton(Key key) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    await tap(finder);
    await pumpThroughAnimations();
    return this;
  }

  /// Asserts the button with [key] is enabled.
  Future<WidgetTester> expectButtonEnabled(Key key) async {
    expect(_buttonEnabled(key), isTrue);
    return this;
  }

  /// Asserts the button with [key] is disabled.
  Future<WidgetTester> expectButtonDisabled(Key key) async {
    expect(_buttonEnabled(key), isFalse);
    return this;
  }

  bool _buttonEnabled(Key key) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    final buttonWidget = widget(finder);

    for (final resolver in activeHarnessConfig.buttonResolvers) {
      final resolved = resolver(buttonWidget);
      if (resolved != null) return resolved;
    }

    return switch (buttonWidget) {
      final ButtonStyleButton b => b.onPressed != null || b.onLongPress != null,
      final InkWell w => w.onTap != null,
      final GestureDetector g => g.onTap != null,
      _ => fail(
        'Widget with key $key is not a recognised button. Register a '
        'ButtonResolver in HarnessConfig.',
      ),
    };
  }

  /// Enters [text] into the [TextField] at or under [key].
  Future<WidgetTester> enterTextByKey(Key key, String text) async {
    final field = _fieldUnder<TextField>(key);
    await tap(field);
    await pumpThroughAnimations();
    await enterText(field, text);
    await pumpThroughAnimations();
    return this;
  }

  /// Enters [text] into the [EditableText] (e.g. Pinput) at or under [key].
  Future<WidgetTester> enterPinByKey(Key key, String text) async {
    final field = _fieldUnder<EditableText>(key);
    await enterText(field, text);
    await pumpThroughAnimations();
    return this;
  }

  /// Submits the focused text input via the keyboard 'done' action.
  Future<WidgetTester> submitText() async {
    await testTextInput.receiveAction(TextInputAction.done);
    await pumpThroughAnimations();
    return this;
  }

  /// Asserts the [TextField] at or under [key] currently holds [text].
  Future<WidgetTester> expectInputHasText(Key key, String text) async {
    expect(
      widget<TextField>(_fieldUnder<TextField>(key)).controller?.text,
      text,
    );
    return this;
  }

  /// Asserts the [EditableText] at or under [key] currently holds [text].
  Future<WidgetTester> expectPinInputHasText(Key key, String text) async {
    expect(
      widget<EditableText>(_fieldUnder<EditableText>(key)).controller.text,
      text,
    );
    return this;
  }

  /// Asserts the [TextField] at or under [key] has focus.
  Future<WidgetTester> expectInputHasFocus(Key key) async {
    expect(
      widget<TextField>(_fieldUnder<TextField>(key)).focusNode?.hasFocus,
      isTrue,
    );
    return this;
  }

  /// Resolves a field of type [T] that is the keyed widget itself or a
  /// descendant of it, so callers may key either the field or a wrapper.
  Finder _fieldUnder<T extends Widget>(Key key) {
    final form = find.byKey(key);
    expect(form, findsOneWidget);
    if (form.evaluate().first.widget is T) return form;
    final field = find.descendant(
      of: form,
      matching: find.byWidgetPredicate((widget) => widget is T),
    );
    expect(field, findsOneWidget);
    return field;
  }

  /// Prints every `ValueKey<String>` in the widget tree (debug aid, R7.3).
  void printOutStringKeys() {
    for (final element in allElements) {
      final key = element.widget.key;
      if (key is ValueKey<String>) {
        print('Element key: ${key.value}');
      }
    }
  }
}
