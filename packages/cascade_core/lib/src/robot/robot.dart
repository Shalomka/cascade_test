import 'package:cascade_core/src/chain/chain_context.dart';
import 'package:cascade_core/src/tester/widget_tester_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

/// Base class for chainable BDD robots (R5.1).
///
/// A robot wraps a [WidgetTester] and exposes intention-revealing, key-driven
/// verbs so tests read Given/When/Then with no raw `find.byType`/`tester.tap`
/// (R5.2). Each verb **enqueues** a labeled step onto a shared [ChainContext]
/// and returns the concrete robot (via the CRTP [Self] type), so a multi-step
/// flow reads as one fluent expression. Nothing executes until a terminal
/// [run] drains the queue in order.
///
/// The [Self] type parameter is a CRTP self-type: concrete robots MUST be a
/// **single leaf** — `class LoginRobot extends Robot<LoginRobot>` — so chains
/// stay fully typed across base + domain verbs. A two-level hierarchy loses
/// subclass verbs mid-chain; keep robots one level, or make an intermediate
/// generic too (`abstract class BaseAppRobot<S extends BaseAppRobot<S>>
/// extends Robot<S>`). See `docs/MIGRATION.md`.
///
/// Chaining is additive and opt-in: a single-verb chain terminated with
/// `.run()` and the raw [WidgetTesterX] extension both remain available as the
/// imperative escape hatch (G7).
abstract class Robot<Self extends Robot<Self>> {
  /// Creates a robot bound to [tester].
  Robot(this.tester);

  /// The tester this robot drives.
  final WidgetTester tester;

  ChainContext? _context;

  /// The receiver, statically typed as the concrete robot [Self].
  Self get self => this as Self;

  /// The active chain context, starting a fresh one when null or consumed (A4).
  ///
  /// A consumed context is inert, so the next chain on a reused robot instance
  /// begins clean with no cross-scenario merge.
  ChainContext get context {
    final current = _context;
    if (current == null || current.consumed) return _context = ChainContext();
    return current;
  }

  /// Enqueues a [label]ed [thunk] as a chain step and returns [self].
  ///
  /// Every verb funnels through here so labels stay per-step (A3). The result
  /// is `@useResult`: discarding it means the chain is never run, which the
  /// analyzer flags.
  @useResult
  Self step(String label, Future<void> Function() thunk) {
    context.enqueue(label, thunk);
    return self;
  }

  /// Hops to [next] on the SAME shared queue and returns it (A5).
  ///
  /// Asserts [next] shares this robot's [tester] and has no pending chain, then
  /// transfers the active context so a cross-robot scenario drains as one
  /// ordered queue.
  @useResult
  R on<R extends Robot<R>>(R next) {
    assert(
      identical(next.tester, tester),
      '`.on()` requires the next robot to share this tester (flow-gap #5).',
    );
    assert(
      next._context == null || next._context!.consumed,
      '`.on()` target already has a pending chain (A5).',
    );
    next._context = context;
    return next;
  }

  /// Terminal: drains the queue in order (A2).
  ///
  /// The only awaitable in a chain. A failing step throws a [ChainStepError]
  /// naming the step; a second [run] on a drained chain throws [StateError].
  Future<void> run() => context.run();

  // --- R4.3 primitive verbs: each enqueues ONE labeled step (A3) ---

  /// Asserts the widget with [key] is visible.
  @useResult
  Self expectVisible(Key key) =>
      step('expectVisible($key)', () => tester.expectWidget(key));

  /// Asserts the widget with [key] is not present.
  @useResult
  Self expectNotVisible(Key key) =>
      step('expectNotVisible($key)', () => tester.expectNoWidget(key));

  /// Asserts the widget with [key] displays [text].
  @useResult
  Self expectText(Key key, String text) =>
      step('expectText($key,$text)', () => tester.expectText(key, text));

  /// Taps the widget with [key].
  @useResult
  Self tap(Key key) => step('tap($key)', () => tester.tapButton(key));

  /// Enters [text] into the field under [key].
  @useResult
  Self enterText(Key key, String text) =>
      step('enterText($key)', () => tester.enterTextByKey(key, text));

  /// Waits until the widget with [key] appears (deterministic; never settle).
  @useResult
  Self pumpUntilVisible(
    Key key, {
    Duration timeout = const Duration(seconds: 10),
  }) => step(
    'pumpUntilVisible($key)',
    () => tester.pumpUntil(find.byKey(key), timeout: timeout),
  );

  /// Taps the widget with [key] only if it is currently present (R5.3).
  ///
  /// The tree is inspected **inside the thunk** at run time, not at enqueue
  /// time, so a widget produced by an earlier chained step is seen
  /// (flow-gap #7).
  @useResult
  Self tapIfPresent(Key key) => step('tapIfPresent($key)', () async {
    if (find.byKey(key).evaluate().isNotEmpty) {
      await tester.tapButton(key);
    }
  });
}
