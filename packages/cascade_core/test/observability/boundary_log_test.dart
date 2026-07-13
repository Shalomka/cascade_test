import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = BoundaryRequest(
    kind: BoundaryKind.http,
    method: 'GET',
    endpoint: '/policies',
  );

  group('formatBoundaryCall (R7.1)', () {
    test('formats a RespondWith outcome as status + latency', () {
      const resolved = ResolvedOutcome(
        outcome: RespondWith(BoundaryResponse(statusCode: 200)),
        latency: Duration(milliseconds: 5),
      );

      expect(
        formatBoundaryCall(request, resolved),
        '[boundary] GET /policies -> status 200 (5ms)',
      );
    });

    test('formats a RespondWithHandler outcome as a static marker (CR-1)', () {
      final resolved = ResolvedOutcome(
        outcome: RespondWithHandler(
          (_) => const BoundaryResponse(statusCode: 200),
        ),
        latency: const Duration(milliseconds: 5),
      );

      // The log runs before the handler executes, so it has no status/body.
      expect(
        formatBoundaryCall(request, resolved),
        '[boundary] GET /policies -> handler (5ms)',
      );
    });

    test('formats a FailWith outcome as its error kind', () {
      const resolved = ResolvedOutcome(
        outcome: FailWith(BoundaryError(kind: BoundaryErrorKind.timeout)),
        latency: Duration(milliseconds: 12),
      );

      expect(
        formatBoundaryCall(request, resolved),
        '[boundary] GET /policies -> error timeout (12ms)',
      );
    });
  });

  group('logBoundaryCall (R7.1)', () {
    test('prints the formatted boundary call to the console', () {
      const callable = BoundaryRequest(
        kind: BoundaryKind.callable,
        method: 'CALL',
        endpoint: 'createOrder',
      );
      const resolved = ResolvedOutcome(
        outcome: FailWith(BoundaryError(kind: BoundaryErrorKind.callable)),
        latency: Duration.zero,
      );

      expect(
        () => logBoundaryCall(callable, resolved),
        prints('[boundary] CALL createOrder -> error callable (0ms)\n'),
      );
    });
  });
}
