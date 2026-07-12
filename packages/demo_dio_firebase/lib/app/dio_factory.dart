import 'package:dio/dio.dart';

/// Builds the app's real [Dio] with a production-shaped interceptor stack:
/// an auth-header interceptor and a 403 → refresh → retry interceptor.
///
/// The retry re-issues the original request exactly once, which — against a
/// `403, 200` stub sequence — turns a single user action into the two boundary
/// calls the acceptance test asserts (R2.6). This interceptor logic is the
/// system under test; the harness never simulates it.
Dio createAppDio({String baseUrl = 'https://api.demo'}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['authorization'] = 'Bearer token';
        handler.next(options);
      },
      onError: (error, handler) async {
        final isForbidden = error.response?.statusCode == 403;
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        if (isForbidden && !alreadyRetried) {
          final options = error.requestOptions;
          options.extra['retried'] = true;
          options.headers['authorization'] = 'Bearer refreshed-token';
          try {
            final response = await dio.fetch<dynamic>(options);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.reject(retryError);
          }
          return;
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}
