import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/minimal_app.dart';

class _ScreenRobot extends Robot<_ScreenRobot> {
  _ScreenRobot(super.tester);

  static const title = Key('title');
  static const cta = Key('cta');
  static const optional = Key('optional');

  /// A composite domain verb: taps the CTA then waits for the optional widget.
  /// Composed from primitives so each sub-action is its own labeled step (A3).
  _ScreenRobot revealOptional() => tap(cta).pumpUntilVisible(optional);
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
    testWidgets('a chain of verbs drives a real tree end-to-end (R5.1)', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));

      await _ScreenRobot(tester)
          .expectVisible(_ScreenRobot.title)
          .expectText(_ScreenRobot.title, 'Welcome')
          .expectNotVisible(_ScreenRobot.optional)
          .tap(_ScreenRobot.cta)
          .expectVisible(_ScreenRobot.optional)
          .run();
    });

    testWidgets('verbs enqueue lazily and run drains in order', (tester) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));
      final robot = _ScreenRobot(tester);

      // Enqueue three steps without running. Capturing the returned robot
      // satisfies `@useResult`; the chain is drained below via `run()`.
      final built = robot
          .expectVisible(_ScreenRobot.title)
          .tap(_ScreenRobot.cta)
          .expectVisible(_ScreenRobot.optional);
      expect(identical(built, robot), isTrue, reason: 'verbs return self');

      expect(robot.context.length, 3, reason: 'steps enqueue synchronously');
      // The tap has not executed yet: the optional widget must be absent.
      expect(find.byKey(_ScreenRobot.optional), findsNothing);

      await robot.run();

      expect(find.byKey(_ScreenRobot.optional), findsOneWidget);
    });

    testWidgets(
      'a composite verb enqueues one labeled step per primitive (A3)',
      (tester) async {
        await tester.pumpWidget(const MinimalApp(child: _Screen()));
        final robot = _ScreenRobot(tester).revealOptional();

        // revealOptional() composes tap + pumpUntilVisible → two labeled steps.
        expect(robot.context.length, 2);

        await robot.run();
        expect(find.byKey(_ScreenRobot.optional), findsOneWidget);
      },
    );

    testWidgets('tapIfPresent is a no-op when the widget is absent (R5.3)', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));

      // The optional widget is not present yet: this must not throw.
      await _ScreenRobot(tester)
          .tapIfPresent(_ScreenRobot.optional)
          .expectNotVisible(_ScreenRobot.optional)
          .run();
    });
  });
}
