import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/minimal_app.dart';

class _Robot extends Robot<_Robot> {
  _Robot(super.tester);

  static const title = Key('title');
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return const Text('Welcome', key: _Robot.title);
  }
}

void main() {
  group('ChainStepError output (CH-AC4)', () {
    testWidgets('a failing mid-chain step names step i/n and its label', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));

      // Step 2 of 3 fails: `title` is present, so expectNotVisible fails.
      final chain = _Robot(tester)
          .expectVisible(_Robot.title) // step 1/3 — passes
          .expectNotVisible(_Robot.title) // step 2/3 — fails
          .expectVisible(_Robot.title); // step 3/3 — never runs

      await expectLater(
        chain.run,
        throwsA(
          isA<ChainStepError>()
              .having((e) => e.index, 'index', 1)
              .having((e) => e.total, 'total', 3)
              .having((e) => e.label, 'label', contains('expectNotVisible'))
              .having((e) => e.toString(), 'toString', contains('step 2/3')),
        ),
      );
    });

    testWidgets('the original matcher expected/actual diff survives (C3)', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Screen()));

      // The wrapped cause is the underlying TestFailure, and its matcher diff
      // (expected/actual) is preserved verbatim in the message.
      await expectLater(
        _Robot(tester).expectText(_Robot.title, 'Nope').run,
        throwsA(
          isA<ChainStepError>()
              .having((e) => e.cause, 'cause', isA<TestFailure>())
              .having((e) => e.toString(), 'toString', contains('Expected'))
              .having((e) => e.toString(), 'toString', contains('Welcome')),
        ),
      );
    });
  });
}
