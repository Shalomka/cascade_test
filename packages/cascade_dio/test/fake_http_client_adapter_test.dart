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
