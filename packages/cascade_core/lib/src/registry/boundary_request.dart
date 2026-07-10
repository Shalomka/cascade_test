import 'package:meta/meta.dart';

/// The kind of I/O boundary a [BoundaryRequest] represents.
///
/// Both kinds flow through the same `StubRegistry` so matching, sequencing,
/// latency, recording and fail-fast behave identically for HTTP routes and
/// Firebase callables.
enum BoundaryKind {
  /// An HTTP request (dio or package:http transports).
  http,

  /// A Firebase callable-function invocation.
  callable,
}

/// A transport-agnostic description of an outbound call at the I/O boundary.
///
/// This is the single key type the harness matches stubs against. Adapters
/// (dio/http/firebase) translate their native request objects into a
/// [BoundaryRequest] and never leak transport types into the core.
@immutable
final class BoundaryRequest {
  /// Creates a [BoundaryRequest].
  const BoundaryRequest({
    required this.kind,
    required this.method,
    required this.endpoint,
    this.body,
    this.query = const <String, dynamic>{},
    this.headers = const <String, String>{},
  });

  /// Whether this is an HTTP or callable boundary.
  final BoundaryKind kind;

  /// The HTTP verb (`GET`, `POST`, ...). Callables use `CALL`.
  final String method;

  /// The URL path (HTTP) or the callable name (functions).
  final String endpoint;

  /// The decoded request payload, if any.
  final Object? body;

  /// The query parameters, if any.
  final Map<String, dynamic> query;

  /// The request headers, if any.
  final Map<String, String> headers;

  @override
  String toString() => 'BoundaryRequest($method $endpoint, kind: ${kind.name})';
}
