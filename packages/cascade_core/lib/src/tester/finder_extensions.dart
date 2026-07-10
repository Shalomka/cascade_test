import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text assertions over a [Finder]'s evaluated widgets.
extension FinderTextX on Finder {
  /// The `data` of every [Text] widget among this finder's evaluated widgets.
  List<String> textValues() => evaluate()
      .map((element) => element.widget)
      .whereType<Text>()
      .map((text) => text.data ?? '')
      .toList();

  /// Asserts some evaluated [Text] widget carries [value].
  void verifyText(String value) => expect(textValues(), contains(value));
}
