import 'package:cascade_core/src/registry/boundary_request.dart';
import 'package:cascade_core/src/registry/call_recorder.dart';
import 'package:cascade_core/src/registry/missing_stub_error.dart';
import 'package:cascade_core/src/registry/stub.dart';

/// The outcome the registry resolved for a request, plus its effective latency.
final class ResolvedOutcome {
  /// Creates a [ResolvedOutcome].
  const ResolvedOutcome({required this.outcome, required this.latency});

  /// The selected [StubOutcome] (a [RespondWith] or [FailWith]).
  final StubOutcome outcome;

  /// The effective latency to apply before delivering the outcome (R2.5).
  final Duration latency;
}

/// The single shared source of truth for stubbed boundary calls.
///
/// Both HTTP routes and Firebase callables resolve through one registry so
/// matching (R2.4), sequencing (R2.6), latency (R2.5), recording (R2.7) and
/// fail-fast (R2.3) behave identically across transports.
final class StubRegistry {
  final List<Stub> _stubs = <Stub>[];

  /// Records every attempted boundary call for later assertions (R2.7).
  final CallRecorder recorder = CallRecorder();

  /// The default per-stub latency, applied when an outcome sets none (R2.5).
  Duration defaultLatency = const Duration(milliseconds: 100);

  /// Optional observer invoked after each successful resolution (R7.1).
  ///
  /// Used by the boundary log to print per-call diagnostics. Not called for
  /// unmatched requests (those throw [MissingStubError]).
  void Function(BoundaryRequest request, ResolvedOutcome outcome)? onResolved;

  /// All registered stubs, in registration order.
  List<Stub> get stubs => List<Stub>.unmodifiable(_stubs);

  /// Registers [stub]. Later registrations override earlier overlapping ones
  /// because [resolve] scans in reverse registration order (R2.4).
  void register(Stub stub) => _stubs.add(stub);

  /// Resolves [request] to an outcome, recording the call first.
  ///
  /// Throws [MissingStubError] when no registered stub matches (R2.3).
  ResolvedOutcome resolve(BoundaryRequest request) {
    recorder.record(request);
    for (var i = _stubs.length - 1; i >= 0; i--) {
      final stub = _stubs[i];
      if (stub.matcher.matches(request)) {
        final outcome = stub.next();
        final resolved = ResolvedOutcome(
          outcome: outcome,
          latency: outcome.latency ?? defaultLatency,
        );
        onResolved?.call(request, resolved);
        return resolved;
      }
    }
    throw MissingStubError(request);
  }

  /// Clears all stubs and recorded calls.
  void reset() {
    _stubs.clear();
    recorder.clear();
  }
}
