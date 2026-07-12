import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_dio/cascade_dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapRequestOptions', () {
    test('maps method, path, query, body and headers', () {
      final options = RequestOptions(
        path: '/orders',
        method: 'POST',
        baseUrl: 'https://api.test',
        queryParameters: {'page': 2},
        data: {'sku': 'abc'},
        headers: {'authorization': 'Bearer token'},
      );

      final request = mapRequestOptions(options);

      expect(request.kind, BoundaryKind.http);
      expect(request.method, 'POST');
      expect(request.endpoint, '/orders');
      expect(request.query['page'], 2);
      expect(request.body, {'sku': 'abc'});
      expect(request.headers['authorization'], 'Bearer token');
    });

    test('derives the path from the composed URI', () {
      final options = RequestOptions(
        path: '/policies',
        baseUrl: 'https://api.test/v1',
      );

      expect(mapRequestOptions(options).endpoint, '/v1/policies');
    });
  });
}
