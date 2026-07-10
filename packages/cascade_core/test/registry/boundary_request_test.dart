import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoundaryRequest', () {
    test('defaults query and headers to empty maps', () {
      const request = BoundaryRequest(
        kind: BoundaryKind.http,
        method: 'GET',
        endpoint: '/policies',
      );

      expect(request.query, isEmpty);
      expect(request.headers, isEmpty);
      expect(request.body, isNull);
    });

    test('retains provided fields', () {
      const request = BoundaryRequest(
        kind: BoundaryKind.callable,
        method: 'CALL',
        endpoint: 'createOrder',
        body: {'sku': 'abc'},
        query: {'page': 1},
        headers: {'authorization': 'Bearer x'},
      );

      expect(request.kind, BoundaryKind.callable);
      expect(request.method, 'CALL');
      expect(request.endpoint, 'createOrder');
      expect(request.body, {'sku': 'abc'});
      expect(request.query, {'page': 1});
      expect(request.headers, {'authorization': 'Bearer x'});
    });

    test('toString includes method and endpoint', () {
      const request = BoundaryRequest(
        kind: BoundaryKind.http,
        method: 'POST',
        endpoint: '/orders',
      );

      expect(request.toString(), contains('POST'));
      expect(request.toString(), contains('/orders'));
    });
  });
}
