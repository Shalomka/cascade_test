import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_dio/cascade_dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Dio _dio(StubRegistry registry) => Dio(
  BaseOptions(baseUrl: 'https://api.test'),
)..httpClientAdapter = FakeHttpClientAdapter(registry);

void main() {
  group('FakeHttpClientAdapter', () {
    late StubRegistry registry;

    setUp(() => registry = StubRegistry()..defaultLatency = Duration.zero);

    test('resolves a GET after real interceptors run', () async {
      registry.register(
        Stub(
          matcher: const RequestMatcher('GET', '/policies'),
          outcomes: const [
            RespondWith(BoundaryResponse(statusCode: 200, body: {'ok': true})),
          ],
        ),
      );
      final dio = _dio(registry)
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              options.headers['x-interceptor'] = 'ran';
              handler.next(options);
            },
          ),
        );

      final response = await dio.get<Map<String, dynamic>>('/policies');

      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
      // The real interceptor ran before the adapter recorded the call.
      expect(
        registry.recorder.calls.single.request.headers['x-interceptor'],
        'ran',
      );
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
        final dio = _dio(registry);

        final response = await dio.get<Map<String, dynamic>>('/echo');

        expect(response.statusCode, 200);
        expect(response.data, {'path': '/echo'});
        // The single adapter await guarantees one invocation per resolution.
        expect(calls, 1);
      },
    );

    test(
      'a stubbed 403 then 200 sequence surfaces a real DioException (D4)',
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
        final dio = _dio(registry);

        DioException? firstError;
        try {
          await dio.post<dynamic>('/orders');
        } on DioException catch (error) {
          firstError = error;
        }

        expect(firstError, isNotNull);
        expect(firstError!.response?.statusCode, 403);
        expect(firstError.type, DioExceptionType.badResponse);

        final second = await dio.post<Map<String, dynamic>>('/orders');
        expect(second.statusCode, 200);
        expect(second.data, {'id': 'o1'});
      },
    );

    test(
      'an injected transport failure raises a native DioException',
      () async {
        registry.register(
          Stub(
            matcher: const RequestMatcher('GET', '/slow'),
            outcomes: const [
              FailWith(BoundaryError(kind: BoundaryErrorKind.timeout)),
            ],
          ),
        );
        final dio = _dio(registry);

        DioException? error;
        try {
          await dio.get<dynamic>('/slow');
        } on DioException catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(error!.type, DioExceptionType.receiveTimeout);
      },
    );

    test(
      'maps each non-timeout BoundaryErrorKind to a faithful '
      'DioExceptionType',
      () async {
        const cases = <BoundaryErrorKind, DioExceptionType>{
          BoundaryErrorKind.connection: DioExceptionType.connectionError,
          BoundaryErrorKind.cancel: DioExceptionType.cancel,
          BoundaryErrorKind.badResponse: DioExceptionType.badResponse,
          BoundaryErrorKind.callable: DioExceptionType.unknown,
          BoundaryErrorKind.unknown: DioExceptionType.unknown,
        };

        for (final entry in cases.entries) {
          final localRegistry = StubRegistry()
            ..defaultLatency = Duration.zero
            ..register(
              Stub(
                matcher: const RequestMatcher('GET', '/fail'),
                outcomes: [
                  FailWith(BoundaryError(kind: entry.key, message: 'boom')),
                ],
              ),
            );
          final dio = _dio(localRegistry);

          DioException? error;
          try {
            await dio.get<dynamic>('/fail');
          } on DioException catch (e) {
            error = e;
          }

          expect(error, isNotNull, reason: '${entry.key} should raise');
          expect(error!.type, entry.value, reason: 'kind ${entry.key}');
          expect(error.message, 'boom');
          // No statusCode on the error → no attached response.
          expect(error.response, isNull);
        }
      },
    );

    test(
      'attaches a Response carrying the error statusCode and body',
      () async {
        registry.register(
          Stub(
            matcher: const RequestMatcher('GET', '/fail'),
            outcomes: const [
              FailWith(
                BoundaryError(
                  kind: BoundaryErrorKind.badResponse,
                  statusCode: 503,
                  body: {'reason': 'down'},
                ),
              ),
            ],
          ),
        );
        final dio = _dio(registry);

        DioException? error;
        try {
          await dio.get<dynamic>('/fail');
        } on DioException catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(error!.response, isNotNull);
        expect(error.response!.statusCode, 503);
        expect(error.response!.data, {'reason': 'down'});
      },
    );

    test('applies the configured latency before responding (R2.5)', () async {
      registry
        ..defaultLatency = const Duration(milliseconds: 120)
        ..register(
          Stub(
            matcher: const RequestMatcher('GET', '/policies'),
            outcomes: const [RespondWith(BoundaryResponse(statusCode: 200))],
          ),
        );
      final dio = _dio(registry);

      final stopwatch = Stopwatch()..start();
      await dio.get<dynamic>('/policies');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });

    test('an unstubbed call surfaces a MissingStubError (AC2)', () async {
      final dio = _dio(registry);

      DioException? error;
      try {
        await dio.get<dynamic>('/nope');
      } on DioException catch (e) {
        error = e;
      }

      expect(error, isNotNull);
      expect(error!.error, isA<MissingStubError>());
      final missing = error.error! as MissingStubError;
      expect(missing.message, contains('GET'));
      expect(missing.message, contains('/nope'));
    });
  });
}
