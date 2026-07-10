import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

BoundaryRequest _get(String endpoint) => BoundaryRequest(
  kind: BoundaryKind.http,
  method: 'GET',
  endpoint: endpoint,
);

void main() {
  group('StubRegistry', () {
    late StubRegistry registry;

    setUp(() => registry = StubRegistry());

    test('resolves a registered stub', () {
      registry.register(
        Stub(
          matcher: const RequestMatcher('GET', '/policies'),
          outcomes: const [
            RespondWith(BoundaryResponse(statusCode: 200, body: {'ok': true})),
          ],
        ),
      );

      final resolved = registry.resolve(_get('/policies'));
      final outcome = resolved.outcome;

      expect(outcome, isA<RespondWith>());
      expect((outcome as RespondWith).response.statusCode, 200);
    });

    test('throws MissingStubError for an unmatched request', () {
      expect(
        () => registry.resolve(_get('/unknown')),
        throwsA(isA<MissingStubError>()),
      );
    });

    test('later registration overrides an earlier overlapping stub (R2.4)', () {
      registry
        ..register(
          Stub(
            matcher: const RequestMatcher('GET', '/policies'),
            outcomes: const [RespondWith(BoundaryResponse(statusCode: 200))],
          ),
        )
        ..register(
          Stub(
            matcher: const RequestMatcher('GET', '/policies'),
            outcomes: const [RespondWith(BoundaryResponse(statusCode: 503))],
          ),
        );

      final resolved = registry.resolve(_get('/policies'));

      expect((resolved.outcome as RespondWith).response.statusCode, 503);
    });

    test('advances through a sequence and clamps at the last (R2.6)', () {
      registry.register(
        Stub(
          matcher: const RequestMatcher('POST', '/orders'),
          outcomes: const [
            RespondWith(BoundaryResponse(statusCode: 403)),
            RespondWith(BoundaryResponse(statusCode: 200)),
          ],
        ),
      );

      BoundaryRequest post() => const BoundaryRequest(
        kind: BoundaryKind.http,
        method: 'POST',
        endpoint: '/orders',
      );

      expect(
        (registry.resolve(post()).outcome as RespondWith).response.statusCode,
        403,
      );
      expect(
        (registry.resolve(post()).outcome as RespondWith).response.statusCode,
        200,
      );
      expect(
        (registry.resolve(post()).outcome as RespondWith).response.statusCode,
        200,
      );
    });

    test('applies the default latency when the outcome sets none (R2.5)', () {
      registry
        ..defaultLatency = const Duration(milliseconds: 250)
        ..register(
          Stub(
            matcher: const RequestMatcher('GET', '/policies'),
            outcomes: const [RespondWith(BoundaryResponse(statusCode: 200))],
          ),
        );

      expect(
        registry.resolve(_get('/policies')).latency,
        const Duration(milliseconds: 250),
      );
    });

    test('a per-outcome latency overrides the default (R2.5)', () {
      registry.register(
        Stub(
          matcher: const RequestMatcher('GET', '/policies'),
          outcomes: const [
            RespondWith(
              BoundaryResponse(statusCode: 200),
              latency: Duration(milliseconds: 5),
            ),
          ],
        ),
      );

      expect(
        registry.resolve(_get('/policies')).latency,
        const Duration(milliseconds: 5),
      );
    });

    test('records every attempted call, including failures (R2.7)', () {
      registry
        ..register(
          Stub(
            matcher: const RequestMatcher('GET', '/policies'),
            outcomes: const [RespondWith(BoundaryResponse(statusCode: 200))],
          ),
        )
        ..resolve(_get('/policies'));
      expect(
        () => registry.resolve(_get('/missing')),
        throwsA(isA<MissingStubError>()),
      );

      expect(registry.recorder.calls, hasLength(2));
    });

    test('reset clears stubs and recorded calls', () {
      registry
        ..register(
          Stub(
            matcher: const RequestMatcher('GET', '/policies'),
            outcomes: const [RespondWith(BoundaryResponse(statusCode: 200))],
          ),
        )
        ..resolve(_get('/policies'))
        ..reset();

      expect(registry.stubs, isEmpty);
      expect(registry.recorder.calls, isEmpty);
      expect(
        () => registry.resolve(_get('/policies')),
        throwsA(isA<MissingStubError>()),
      );
    });
  });
}
