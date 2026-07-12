import 'package:meta/meta.dart';

/// One labeled, deferred step in a chain.
///
/// The `label` feeds [ChainStepError] so a failing step reports which verb
/// failed. The `thunk` is the deferred work — nothing runs until
/// [ChainContext.run] drains the queue.
typedef ChainStep = ({String label, Future<void> Function() thunk});

/// The lazy step-queue shared by a chain.
///
/// One instance is shared across every robot reached via `.on()` in a single
/// scenario, so a cross-robot chain drains as a single ordered queue. Robot
/// verbs [enqueue] labeled steps synchronously; [run] executes them in order.
class ChainContext {
  final List<ChainStep> _steps = [];

  /// Whether this context has been drained by [run].
  ///
  /// A consumed context is inert: the owning robot starts a fresh one for the
  /// next chain (A4 lifecycle), and a second [run] throws.
  bool consumed = false;

  /// Appends a labeled deferred [thunk] to the queue. Never executes it.
  void enqueue(String label, Future<void> Function() thunk) =>
      _steps.add((label: label, thunk: thunk));

  /// The number of steps enqueued so far.
  int get length => _steps.length;

  /// Drains steps in order.
  ///
  /// On the first failing step, rethrows a [ChainStepError] naming
  /// `step (i+1)/n · <label>` while preserving the original stack trace and
  /// matcher diff (C3). Marks [consumed] in a `finally` so the owning robot
  /// starts fresh next time (A4 lifecycle). A second call throws [StateError];
  /// an empty queue completes as a no-op.
  Future<void> run() async {
    if (consumed) {
      throw StateError(
        'This chain has already been run (A4). Build a new chain.',
      );
    }
    try {
      for (var i = 0; i < _steps.length; i++) {
        final step = _steps[i];
        try {
          await step.thunk();
        } catch (e, s) {
          Error.throwWithStackTrace(
            ChainStepError(
              index: i,
              total: _steps.length,
              label: step.label,
              cause: e,
            ),
            s, // preserve the ORIGINAL stack + matcher diff (C3).
          );
        }
      }
    } finally {
      consumed = true;
    }
  }
}

/// Thrown by [ChainContext.run] when a step fails.
///
/// [toString] names `step (index+1)/total · <label>` and appends the original
/// [cause] verbatim, so the failing verb and the underlying matcher diff both
/// survive (C3). The original stack trace is preserved by the thrower via
/// [Error.throwWithStackTrace].
@immutable
class ChainStepError extends Error {
  /// Creates a [ChainStepError] for the step at [index] (0-based) of [total],
  /// labeled [label], wrapping [cause].
  ChainStepError({
    required this.index,
    required this.total,
    required this.label,
    required this.cause,
  });

  /// The 0-based index of the failing step within the drained queue.
  final int index;

  /// The total number of steps in the drained queue.
  final int total;

  /// The failing step's label (the verb that enqueued it).
  final String label;

  /// The original error thrown by the step's thunk.
  final Object cause;

  @override
  String toString() =>
      'ChainStepError: step ${index + 1}/$total · $label\n$cause';
}
