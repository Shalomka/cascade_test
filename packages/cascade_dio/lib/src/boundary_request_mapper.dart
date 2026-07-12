import 'package:cascade_core/cascade_core.dart';
import 'package:dio/dio.dart';

/// Translates a dio [RequestOptions] into a transport-agnostic
/// [BoundaryRequest] the shared [StubRegistry] can match.
BoundaryRequest mapRequestOptions(RequestOptions options) {
  return BoundaryRequest(
    kind: BoundaryKind.http,
    method: options.method,
    endpoint: options.uri.path,
    body: options.data,
    query: Map<String, dynamic>.from(options.queryParameters),
    headers: options.headers.map(
      (key, value) => MapEntry(key, '$value'),
    ),
  );
}
