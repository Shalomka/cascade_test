import 'dart:convert';
import 'dart:typed_data';

import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_dio/src/boundary_request_mapper.dart';
import 'package:dio/dio.dart';

/// A dio [HttpClientAdapter] that resolves requests against the shared
/// [StubRegistry] instead of hitting the network (R2.2, D4).
///
/// Crucially, a stubbed non-2xx status is returned as a real
/// [ResponseBody] — dio's own `validateStatus` then raises a genuine
/// [DioException], so the app's production error mapping (e.g.
/// `ApiClientException.fromDioError`) runs as the system under test. The
/// harness never constructs an app-level exception.
final class FakeHttpClientAdapter implements HttpClientAdapter {
  /// Creates an adapter bound to [registry].
  FakeHttpClientAdapter(this.registry);

  /// The shared registry every request resolves through.
  final StubRegistry registry;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = mapRequestOptions(options);
    final resolved = registry.resolve(request);
    await Future<void>.delayed(resolved.latency);
    // A statement (not an expression) so the handler is awaited exactly once
    // before the response body is built (CR1-S2).
    switch (resolved.outcome) {
      case RespondWith(:final response):
        return _toResponseBody(response);
      case RespondWithHandler(:final handler):
        final response = await handler(request);
        return _toResponseBody(response);
      case FailWith(:final error):
        throw _toDioException(error, options);
    }
  }

  ResponseBody _toResponseBody(BoundaryResponse response) {
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...response.headers.map(
          (key, value) => MapEntry(key, [value]),
        ),
      },
    );
  }

  @override
  void close({bool force = false}) {}

  DioException _toDioException(BoundaryError error, RequestOptions options) {
    final type = switch (error.kind) {
      BoundaryErrorKind.timeout => DioExceptionType.receiveTimeout,
      BoundaryErrorKind.connection => DioExceptionType.connectionError,
      BoundaryErrorKind.cancel => DioExceptionType.cancel,
      BoundaryErrorKind.badResponse => DioExceptionType.badResponse,
      BoundaryErrorKind.callable => DioExceptionType.unknown,
      BoundaryErrorKind.unknown => DioExceptionType.unknown,
    };
    return DioException(
      requestOptions: options,
      type: type,
      message: error.message,
      response: error.statusCode == null
          ? null
          : Response<Object?>(
              requestOptions: options,
              statusCode: error.statusCode,
              data: error.body,
            ),
    );
  }
}
