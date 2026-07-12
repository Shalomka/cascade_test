import 'dart:convert';

import 'package:cascade_core/src/registry/boundary_request.dart';

/// Thrown when a [BoundaryRequest] reaches the registry with no matching stub.
///
/// The [message] deliberately contains the HTTP method, the full endpoint, and
/// the request payload so an unstubbed call fails fast with an actionable
/// diagnostic (R2.3 / AC2).
final class MissingStubError extends Error {
  /// Creates a [MissingStubError] for the unmatched [request].
  MissingStubError(this.request);

  /// The request that could not be matched.
  final BoundaryRequest request;

  /// A human-readable diagnostic containing method, endpoint and payload.
  String get message {
    final buffer = StringBuffer()
      ..write('No stub registered for ')
      ..write(request.method)
      ..write(' ')
      ..write(request.endpoint);
    if (request.query.isNotEmpty) {
      buffer
        ..write(' query=')
        ..write(_encode(request.query));
    }
    if (request.body != null) {
      buffer
        ..write(' body=')
        ..write(_encode(request.body));
    }
    buffer.write(
      '. Register it on the harness before driving this boundary.',
    );
    return buffer.toString();
  }

  String _encode(Object? value) {
    try {
      return jsonEncode(value);
    } on Object {
      return value.toString();
    }
  }

  @override
  String toString() => 'MissingStubError: $message';
}
