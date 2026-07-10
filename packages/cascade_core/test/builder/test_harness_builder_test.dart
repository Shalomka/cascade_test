import 'package:bloc/bloc.dart';
import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _MarkerInstaller extends TransportInstaller {
  const _MarkerInstaller();

  @override
  void install(Harness harness) => harness.put<String>('installed-by-marker');
}

BoundaryRequest _get(String endpoint) => BoundaryRequest(
  kind: BoundaryKind.http,
  method: 'GET',
  endpoint: endpoint,
);

BoundaryRequest _post(String endpoint, {Object? body}) => BoundaryRequest(
  kind: BoundaryKind.http,
  method: 'POST',
  endpoint: endpoint,
  body: body,
);

void main() {
  late BlocObserver originalObserver;

  setUp(() => originalObserver = Bloc.observer);
  tearDown(() => Bloc.observer = originalObserver);

  group('TestHarnessBuilder', () {
    test('HTTP verbs register stubs on the shared registry', () {
      final builder = TestHarnessBuilder()
        ..withGet('/policies', data: {'items': <dynamic>[]});

      final resolved = builder.registry.resolve(_get('/policies'));

      expect((resolved.outcome as RespondWith).response.statusCode, 200);
      expect(
        (resolved.outcome as RespondWith).response.body,
        {'items': <dynamic>[]},
      );
    });

    test('withPostSequence programs a 403-then-200 sequence (R2.6)', () {
      final builder = TestHarnessBuilder()
        ..withPostSequence('/orders', const [
          Res(403),
          Res(200, data: {'id': 'o1'}),
        ]);

      expect(
        (builder.registry.resolve(_post('/orders')).outcome as RespondWith)
            .response
            .statusCode,
        403,
      );
      expect(
        (builder.registry.resolve(_post('/orders')).outcome as RespondWith)
            .response
            .statusCode,
        200,
      );
    });

    test('mutators are side-effect-free until buildHarness (R3.2)', () {
      const observer = LoggingObserver();
      final builder = TestHarnessBuilder()..withObserver(observer);

      // No side effect yet: the global observer is untouched.
      expect(Bloc.observer, same(originalObserver));

      builder.buildHarness();

      expect(Bloc.observer, same(observer));
    });

    test('buildHarness runs queued install steps against the harness', () {
      final builder = TestHarnessBuilder()
        ..addInstallStep((harness) => harness.put<int>(42));

      final harness = builder.buildHarness();

      expect(harness.get<int>(), 42);
      expect(harness.registry, same(builder.registry));
    });

    test('useInstaller runs a TransportInstaller at build time (AC3 seam)', () {
      final builder = TestHarnessBuilder()
        ..useInstaller(const _MarkerInstaller());

      final harness = builder.buildHarness();

      expect(harness.get<String>(), 'installed-by-marker');
    });

    test('withBoundaryLog wires the registry onResolved hook (R7.1)', () {
      final builder = TestHarnessBuilder()..withBoundaryLog();

      expect(builder.registry.onResolved, isNull);
      builder.buildHarness();
      expect(builder.registry.onResolved, isNotNull);
    });

    test('withDefaultLatency updates the registry default (R2.5)', () {
      final builder = TestHarnessBuilder()
        ..withDefaultLatency(const Duration(milliseconds: 7));

      expect(builder.registry.defaultLatency, const Duration(milliseconds: 7));
    });

    test('expectCalledWith delegates to the recorder (R2.7)', () {
      final builder = TestHarnessBuilder()
        ..withPost('/orders', data: {'id': 'o1'});

      builder.registry.resolve(_post('/orders', body: {'sku': 'abc'}));

      builder.expectCalledWith(
        '/orders',
        (body) => body is Map && body['sku'] == 'abc',
        method: 'POST',
      );
    });
  });
}
