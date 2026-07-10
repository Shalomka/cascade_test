import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

BoundaryRequest _req({
  String method = 'GET',
  String endpoint = '/policies',
  Object? body,
  Map<String, dynamic> query = const <String, dynamic>{},
}) {
  return BoundaryRequest(
    kind: BoundaryKind.http,
    method: method,
    endpoint: endpoint,
    body: body,
    query: query,
  );
}

void main() {
  group('RequestMatcher', () {
    test('exact matches method and endpoint case-insensitively', () {
      const matcher = RequestMatcher('get', '/policies');

      expect(matcher.matches(_req()), isTrue);
      expect(matcher.matches(_req(method: 'POST')), isFalse);
      expect(matcher.matches(_req(endpoint: '/policies/1')), isFalse);
    });

    test('prefix matches endpoints that start with the value', () {
      const matcher = RequestMatcher.prefix('GET', '/policies');

      expect(matcher.matches(_req()), isTrue);
      expect(matcher.matches(_req(endpoint: '/policies/42')), isTrue);
      expect(matcher.matches(_req(endpoint: '/orders')), isFalse);
    });

    test('pattern matches against a RegExp source', () {
      const matcher = RequestMatcher.pattern('GET', r'^/orders/\d+$');

      expect(matcher.matches(_req(endpoint: '/orders/7')), isTrue);
      expect(matcher.matches(_req(endpoint: '/orders/abc')), isFalse);
    });

    test('query constrains matching to a required subset', () {
      const matcher = RequestMatcher('GET', '/policies', query: {'page': 2});

      expect(matcher.matches(_req(query: {'page': 2})), isTrue);
      expect(matcher.matches(_req(query: {'page': 2, 'size': 10})), isTrue);
      expect(matcher.matches(_req(query: {'page': 1})), isFalse);
      expect(matcher.matches(_req()), isFalse);
    });

    test('body predicate constrains matching', () {
      final matcher = RequestMatcher(
        'POST',
        '/orders',
        body: (body) => body is Map && body['sku'] == 'abc',
      );

      expect(
        matcher.matches(
          _req(
            method: 'POST',
            endpoint: '/orders',
            body: {
              'sku': 'abc',
            },
          ),
        ),
        isTrue,
      );
      expect(
        matcher.matches(
          _req(
            method: 'POST',
            endpoint: '/orders',
            body: {
              'sku': 'xyz',
            },
          ),
        ),
        isFalse,
      );
    });
  });
}
