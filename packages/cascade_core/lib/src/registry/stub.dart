import 'package:cascade_core/src/registry/boundary_response.dart';
import 'package:cascade_core/src/registry/matchers.dart';

/// A single programmed outcome for a matched boundary call.
///
/// Either [RespondWith] (a transport response, including non-2xx) or
/// [FailWith] (a genuine transport failure / callable error). An optional
/// [latency] overrides the registry default for this outcome.
sealed class StubOutcome {
  /// Const base constructor.
  const StubOutcome({this.latency});

  /// A per-outcome latency override (R2.5).
  final Duration? latency;
}

/// Respond with a [BoundaryResponse] (2xx or non-2xx).
final class RespondWith extends StubOutcome {
  /// Creates a [RespondWith] outcome.
  const RespondWith(this.response, {super.latency});

  /// The response to return to the adapter.
  final BoundaryResponse response;
}

/// Fail with a genuine transport [BoundaryError].
final class FailWith extends StubOutcome {
  /// Creates a [FailWith] outcome.
  const FailWith(this.error, {super.latency});

  /// The transport error to raise natively in the adapter.
  final BoundaryError error;
}

/// One matcher paired with an ordered list of [outcomes].
///
/// A single-element list is a plain stub; an N-element list is a sequence
/// (R2.6). The internal cursor advances on each resolution and clamps at the
/// last outcome so repeated calls keep returning the final programmed result.
final class Stub {
  /// Creates a [Stub] with at least one outcome.
  Stub({required this.matcher, required this.outcomes})
    : assert(outcomes.isNotEmpty, 'A stub needs at least one outcome');

  /// The predicate selecting requests for this stub.
  final StubMatcher matcher;

  /// The ordered outcomes; one entry = single, many = sequence.
  final List<StubOutcome> outcomes;

  int _cursor = 0;

  /// The zero-based index of the outcome the next [next] call will return.
  int get cursor => _cursor;

  /// Returns the current outcome and advances the cursor (clamped at the end).
  StubOutcome next() {
    final outcome = outcomes[_cursor];
    if (_cursor < outcomes.length - 1) _cursor++;
    return outcome;
  }
}
