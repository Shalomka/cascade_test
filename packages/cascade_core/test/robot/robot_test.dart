import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/minimal_app.dart';

class _ScreenRobot extends Robot {
  _ScreenRobot(super.tester);

  static const title = Key('title');
  static const cta = Key('cta');
  static const optional = Key('optional');
}

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Welcome', key: _ScreenRobot.title),
        ElevatedButton(
          key: _ScreenRobot.cta,
          onPressed: () => setState(() => _tapped = true),
          child: const Text('Continue'),
        ),
        if (_tapped) const SizedBox(key: _ScreenRobot.optional),
      ],
    );
  }
}

void main() {
  group('Robot', () {
    testWidgets('exposes key-driven expect and tap verbs (R5.1)', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));
      final robot = _ScreenRobot(tester);

      await robot.expectVisible(_ScreenRobot.title);
      await robot.expectText(_ScreenRobot.title, 'Welcome');
      await robot.expectNotVisible(_ScreenRobot.optional);

      await robot.tap(_ScreenRobot.cta);

      await robot.expectVisible(_ScreenRobot.optional);
    });

    testWidgets('tapIfPresent is a no-op when the widget is absent (R5.3)', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));
      final robot = _ScreenRobot(tester);

      // The optional widget is not present yet: this must not throw.
      await robot.tapIfPresent(_ScreenRobot.optional);

      await robot.expectNotVisible(_ScreenRobot.optional);
    });
  });
}
