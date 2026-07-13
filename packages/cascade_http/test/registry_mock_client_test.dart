import 'dart:convert';

import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_http/cascade_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Uri _uri(String path) => Uri.parse('https://api.test$path');

void main() {
  group('registryMockClient', () {
    late StubRegistry registry;
    late http.Client client;

    setUp(() {
      registry = StubRegistry()..defaultLatency = Duration.zero;
      client = registryMockClient(registry);
    });

    test('resolves a GET into a real http.Response', () async {
      registry.register(
        Stub(
          matcher: const RequestMatcher('GET', '/policies'),
          outcomes: const [
            RespondWith(BoundaryResponse(statusCode: 200, body: {'ok': true})),
          ],
        ),
      );

      final response = await client.get(_uri('/policies'));

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), {'ok': true});
    });

    test(
      'a handler computes the response and is invoked exactly once (CR1-S2)',
      () async {
        var calls = 0;
        registry.register(
          Stub(
            matcher: const RequestMatcher('GET', '/echo'),
            outcomes: [
              RespondWithHandler((request) {
                calls++;
                return BoundaryResponse(
                  statusCode: 200,
                  body: {'path': request.endpoint},
                );
              }),
            ],
          ),
        );

        final response = await client.get(_uri('/echo'));

        expect(response.statusCode, 200);
        expect(jsonDecode(response.body), {'path': '/echo'});
        expect(calls, 1);
      },
    );

    test(
      'returns a stubbed 403 then 200 without throwing (D4 analog)',
      () async {
        registry.register(
          Stub(
            matcher: const RequestMatcher('POST', '/orders'),
            outcomes: const [
              RespondWith(BoundaryResponse(statusCode: 403)),
              RespondWith(
                BoundaryResponse(statusCode: 200, body: {'id': 'o1'}),
              ),
            ],
          ),
        );

        final first = await client.post(_uri('/orders'), body: '{}');
        expect(first.statusCode, 403);

        final second = await client.post(_uri('/orders'), body: '{}');
        expect(second.statusCode, 200);
        expect(jsonDecode(second.body), {'id': 'o1'});
      },
    );

    test('an injected failure raises a native ClientException', () async {
      registry.register(
        Stub(
          matcher: const RequestMatcher('GET', '/down'),
          outcomes: const [
            FailWith(BoundaryError(kind: BoundaryErrorKind.connection)),
          ],
        ),
      );

      await expectLater(
        client.get(_uri('/down')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('applies the configured latency (R2.5)', () async {
      registry
        ..defaultLatency = const Duration(milliseconds: 120)
        ..register(
          Stub(
            matcher: const RequestMatcher('GET', '/policies'),
            outcomes: const [RespondWith(BoundaryResponse(statusCode: 200))],
          ),
        );

      final stopwatch = Stopwatch()..start();
      await client.get(_uri('/policies'));
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });

    test('records the decoded request body for expectCalledWith', () async {
      registry.register(
        Stub(
          matcher: const RequestMatcher('POST', '/orders'),
          outcomes: const [RespondWith(BoundaryResponse(statusCode: 200))],
        ),
      );

      await client.post(_uri('/orders'), body: jsonEncode({'sku': 'abc'}));

      registry.recorder.expectCalledWith(
        '/orders',
        (body) => body is Map && body['sku'] == 'abc',
        method: 'POST',
      );
    });

    test('an unstubbed call throws MissingStubError', () async {
      await expectLater(
        client.get(_uri('/nope')),
        throwsA(isA<MissingStubError>()),
      );
    });
  });
}
