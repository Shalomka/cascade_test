import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/minimal_app.dart';

/// A leaf robot over [_Screen] used by the lifecycle acceptance tests.
class _ScreenRobot extends Robot<_ScreenRobot> {
  _ScreenRobot(super.tester);

  static const title = Key('title');
  static const cta = Key('cta');
  static const optional = Key('optional');
  static const done = Key('done');
}

/// A second leaf robot bound to the SAME tester, for cross-robot `.on()`.
class _OtherRobot extends Robot<_OtherRobot> {
  _OtherRobot(super.tester);

  @useResult
  _OtherRobot expectDone() => expectVisible(_ScreenRobot.done);
}

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  bool _optional = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Welcome', key: _ScreenRobot.title),
        ElevatedButton(
          key: _ScreenRobot.cta,
          onPressed: () => setState(() => _optional = true),
          child: const Text('Reveal'),
        ),
        if (_optional)
          ElevatedButton(
            key: _ScreenRobot.optional,
            onPressed: () => setState(() => _done = true),
            child: const Text('Optional'),
          ),
        if (_done) const SizedBox(key: _ScreenRobot.done),
      ],
    );
  }
}

/// A stand-in with a distinct identity for the cross-tester `.on()` guard
/// (CH-AC7). The guard only compares tester identity, so no member is ever
/// invoked. Self-contained on purpose: capturing another test's tester made
/// CH-AC7 order-dependent, which `--test-randomize-ordering-seed` exposes.
class _ForeignTester implements WidgetTester {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Robot chain lifecycle', () {
    testWidgets('CH-AC1: a single-robot chain runs in enqueue order', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));

      await _ScreenRobot(tester)
          .expectVisible(_ScreenRobot.title)
          .expectNotVisible(_ScreenRobot.optional)
          .tap(_ScreenRobot.cta)
          .expectVisible(_ScreenRobot.optional)
          .run();
    });

    testWidgets('CH-AC2: a cross-robot `.on()` chain drains one shared queue', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));
      final screen = _ScreenRobot(tester);
      final other = _OtherRobot(tester);

      await screen
          .tap(_ScreenRobot.cta)
          .tap(_ScreenRobot.optional) // reveals `done`
          .on(other)
          .expectDone()
          .run();

      expect(find.byKey(_ScreenRobot.done), findsOneWidget);
    });

    testWidgets('CH-AC5: reusing a robot starts a fresh context (A4)', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));
      final robot = _ScreenRobot(tester);

      // Scenario 1.
      await robot.expectVisible(_ScreenRobot.title).tap(_ScreenRobot.cta).run();

      // Scenario 2 on the SAME instance: the queue is fresh, not merged.
      final second = robot.expectVisible(_ScreenRobot.optional);
      expect(
        second.context.length,
        1,
        reason: 'the consumed context is replaced, not appended to',
      );
      await second.run();
    });

    testWidgets(
      'CH-AC6: empty run is a no-op; a consumed context re-run throws',
      (tester) async {
        await tester.pumpWidget(const MinimalApp(child: _Screen()));
        final robot = _ScreenRobot(tester);

        // Empty chain: completes as a no-op.
        await robot.run();

        // Build a chain, capture its context, run it, then re-run the SAME
        // consumed context: that throws StateError (A4).
        final built = robot.expectVisible(_ScreenRobot.title);
        final context = built.context;
        await built.run();
        await expectLater(context.run, throwsA(isA<StateError>()));
      },
    );

    testWidgets('CH-AC7: `.on()` onto a different tester throws (A5)', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));
      final onThisTester = _ScreenRobot(tester);
      final onOtherTester = _OtherRobot(_ForeignTester());

      expect(
        () => onThisTester.on(onOtherTester),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('CH-AC8: a conditional step evaluates the tree at run time', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));

      // `optional` does not exist at enqueue time; it is revealed by the
      // earlier `tap(cta)` step. tapIfPresent must find it at DRAIN time and
      // tap it, which reveals `done` (flow-gap #7).
      await _ScreenRobot(tester)
          .tap(_ScreenRobot.cta)
          .tapIfPresent(_ScreenRobot.optional)
          .expectVisible(_ScreenRobot.done)
          .run();
    });

    testWidgets('CH-AC10: the escape hatch still works (G7)', (tester) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));

      // Single-verb chain terminated with `.run()`.
      await _ScreenRobot(tester).expectVisible(_ScreenRobot.title).run();

      // Raw WidgetTesterX interaction, no robot.
      await tester.tapButton(_ScreenRobot.cta);
      await tester.expectWidget(_ScreenRobot.optional);
    });
  });
}
