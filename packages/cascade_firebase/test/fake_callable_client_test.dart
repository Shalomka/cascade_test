import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeCallableClient', () {
    late StubRegistry registry;
    late FakeCallableClient client;

    setUp(() {
      registry = StubRegistry()..defaultLatency = Duration.zero;
      client = FakeCallableClient(registry);
    });

    test('returns stubbed data and records the call (R6.2/R2.7)', () async {
      registry.register(
        Stub(
          matcher: const RequestMatcher('CALL', 'createOrder'),
          outcomes: const [
            RespondWith(BoundaryResponse(statusCode: 200, body: {'id': 'o1'})),
          ],
        ),
      );

      final result = await client.call<Map<String, dynamic>>(
        'createOrder',
        data: {'sku': 'abc'},
      );

      expect(result, {'id': 'o1'});
      registry.recorder.expectCalledWith(
        'createOrder',
        (body) => body is Map && body['sku'] == 'abc',
        method: 'CALL',
      );
    });

    test('throws a real FirebaseFunctionsException on error (D4)', () async {
      registry.register(
        Stub(
          matcher: const RequestMatcher('CALL', 'createOrder'),
          outcomes: const [
            FailWith(
              BoundaryError(
                kind: BoundaryErrorKind.callable,
                code: 'permission-denied',
              ),
            ),
          ],
        ),
      );

      FirebaseFunctionsException? error;
      try {
        await client.call<void>('createOrder');
      } on FirebaseFunctionsException catch (e) {
        error = e;
      }

      expect(error, isNotNull);
      expect(error!.code, 'permission-denied');
    });

    test('sequences and fails fast through the shared registry', () async {
      registry.register(
        Stub(
          matcher: const RequestMatcher('CALL', 'next'),
          outcomes: const [
            RespondWith(BoundaryResponse(statusCode: 200, body: 1)),
            RespondWith(BoundaryResponse(statusCode: 200, body: 2)),
          ],
        ),
      );

      expect(await client.call<int>('next'), 1);
      expect(await client.call<int>('next'), 2);

      await expectLater(
        client.call<int>('unstubbed'),
        throwsA(isA<MissingStubError>()),
      );
    });
  });
}
