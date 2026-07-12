import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChainContext', () {
    test('enqueue does not execute the thunk (lazy)', () {
      final context = ChainContext();
      var ran = false;
      context.enqueue('noop', () async => ran = true);

      expect(context.length, 1);
      expect(ran, isFalse, reason: 'enqueue must defer execution');
    });

    test('run drains steps in enqueue order', () async {
      final context = ChainContext();
      final order = <int>[];
      context
        ..enqueue('a', () async => order.add(1))
        ..enqueue('b', () async => order.add(2))
        ..enqueue('c', () async => order.add(3));

      await context.run();

      expect(order, [1, 2, 3]);
    });

    test('run marks the context consumed', () async {
      final context = ChainContext()..enqueue('a', () async {});
      expect(context.consumed, isFalse);

      await context.run();

      expect(context.consumed, isTrue);
    });

    test(
      'a failing step wraps in ChainStepError naming step i/n and label',
      () async {
        final context = ChainContext()
          ..enqueue('first', () async {})
          ..enqueue('boom', () async => throw StateError('kaboom'))
          ..enqueue('never', () async => fail('must not run past the failure'));

        await expectLater(
          context.run,
          throwsA(
            isA<ChainStepError>()
                .having((e) => e.index, 'index', 1)
                .having((e) => e.total, 'total', 3)
                .having((e) => e.label, 'label', 'boom')
                .having((e) => e.toString(), 'toString', contains('step 2/3'))
                .having((e) => e.toString(), 'toString', contains('boom')),
          ),
        );
      },
    );

    test(
      'ChainStepError preserves the original cause and matcher diff',
      () async {
        final context = ChainContext()
          ..enqueue('assert', () async => expect(1, 2));

        // The original matcher expected/actual survives in the cause (C3).
        await expectLater(
          context.run,
          throwsA(
            isA<ChainStepError>()
                .having((e) => e.cause, 'cause', isA<TestFailure>())
                .having((e) => e.toString(), 'toString', contains('Expected')),
          ),
        );
      },
    );

    test('stops at the first failing step', () async {
      final context = ChainContext();
      var reachedThird = false;
      context
        ..enqueue('ok', () async {})
        ..enqueue('fail', () async => throw StateError('x'))
        ..enqueue('third', () async => reachedThird = true);

      await expectLater(context.run, throwsA(isA<ChainStepError>()));
      expect(reachedThird, isFalse);
    });

    test('a second run on a consumed context throws StateError (A4)', () async {
      final context = ChainContext()..enqueue('a', () async {});
      await context.run();

      await expectLater(context.run, throwsA(isA<StateError>()));
    });

    test('empty run completes as a no-op and marks consumed (A4)', () async {
      final context = ChainContext();

      await context.run();

      expect(context.consumed, isTrue);
    });

    test('consumed is set even when a step throws', () async {
      final context = ChainContext()
        ..enqueue('boom', () async => throw StateError('x'));

      await expectLater(context.run, throwsA(isA<ChainStepError>()));
      expect(
        context.consumed,
        isTrue,
        reason: 'finally must mark consumed on failure too',
      );
    });
  });
}
