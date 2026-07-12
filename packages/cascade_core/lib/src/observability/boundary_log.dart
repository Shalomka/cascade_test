// Boundary logging is a deliberate console-diagnostics feature (R7.1).
// ignore_for_file: avoid_print

import 'package:cascade_core/src/registry/boundary_request.dart';
import 'package:cascade_core/src/registry/stub.dart';
import 'package:cascade_core/src/registry/stub_registry.dart';

/// Formats a single resolved boundary call for logging (R7.1).
String formatBoundaryCall(BoundaryRequest request, ResolvedOutcome outcome) {
  final result = switch (outcome.outcome) {
    RespondWith(:final response) => 'status ${response.statusCode}',
    FailWith(:final error) => 'error ${error.kind.name}',
  };
  return '[boundary] ${request.method} ${request.endpoint} -> $result '
      '(${outcome.latency.inMilliseconds}ms)';
}

/// Prints [formatBoundaryCall] to the console.
///
/// Wired to [StubRegistry.onResolved] by
/// `TestHarnessBuilder.withBoundaryLog`.
void logBoundaryCall(BoundaryRequest request, ResolvedOutcome outcome) {
  print(formatBoundaryCall(request, outcome));
}
