import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MissingStubError', () {
    test('message contains the method and full endpoint (AC2)', () {
      final error = MissingStubError(
        const BoundaryRequest(
          kind: BoundaryKind.http,
          method: 'GET',
          endpoint: '/account/balances/EUR',
        ),
      );

      expect(error.message, contains('GET'));
      expect(error.message, contains('/account/balances/EUR'));
    });

    test('message includes the JSON-encoded body payload', () {
      final error = MissingStubError(
        const BoundaryRequest(
          kind: BoundaryKind.http,
          method: 'POST',
          endpoint: '/orders',
          body: {'sku': 'abc', 'qty': 2},
        ),
      );

      expect(error.message, contains('POST'));
      expect(error.message, contains('/orders'));
      expect(error.message, contains('"sku":"abc"'));
      expect(error.message, contains('"qty":2'));
    });

    test('message includes query parameters when present', () {
      final error = MissingStubError(
        const BoundaryRequest(
          kind: BoundaryKind.http,
          method: 'GET',
          endpoint: '/policies',
          query: {'page': 3},
        ),
      );

      expect(error.message, contains('query='));
      expect(error.message, contains('"page":3'));
    });

    test('toString is prefixed and carries the message', () {
      final error = MissingStubError(
        const BoundaryRequest(
          kind: BoundaryKind.callable,
          method: 'CALL',
          endpoint: 'createOrder',
        ),
      );

      expect(error.toString(), startsWith('MissingStubError:'));
      expect(error.toString(), contains('CALL'));
      expect(error.toString(), contains('createOrder'));
    });
  });
}
