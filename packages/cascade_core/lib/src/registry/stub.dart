import 'dart:async';

import 'package:cascade_core/src/registry/boundary_request.dart';
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

/// Computes its response from the matched request at call time (CR-1).
///
/// Unlike [RespondWith], the body is not baked at config time: the adapter
/// awaits [handler] once, after the outcome's [latency], and delivers its
/// [BoundaryResponse]. Slots into sequences and honors [latency] like any other
/// [StubOutcome].
///
/// Recording and cursor advancement happen in `StubRegistry.resolve` *before*
/// the handler runs, so a handler that throws still consumes its sequence slot
/// and is recorded (R9) — the same semantics as a [FailWith] that throws.
final class RespondWithHandler extends StubOutcome {
  /// Creates a [RespondWithHandler] that computes its [BoundaryResponse] from
  /// the matched [BoundaryRequest].
  const RespondWithHandler(this.handler, {super.latency});

  /// Computes the response from the matched request, awaited once per
  /// resolution after [latency].
  final FutureOr<BoundaryResponse> Function(BoundaryRequest request) handler;
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
