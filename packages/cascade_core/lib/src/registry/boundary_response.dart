import 'package:meta/meta.dart';

/// A transport-shaped response, including non-2xx status codes.
///
/// A non-2xx status is a *success-shaped* outcome (D4): the adapter returns it
/// as a real transport response and lets the app's production error mapping
/// decide it is an error. Genuine transport failures use [BoundaryError].
@immutable
final class BoundaryResponse {
  /// Creates a [BoundaryResponse].
  const BoundaryResponse({
    required this.statusCode,
    this.body,
    this.headers = const <String, String>{},
  });

  /// The HTTP status code (may be non-2xx).
  final int statusCode;

  /// The decoded response payload, if any.
  final Object? body;

  /// The response headers.
  final Map<String, String> headers;

  @override
  String toString() => 'BoundaryResponse($statusCode)';
}

/// The category of a genuine transport failure (not a status code).
enum BoundaryErrorKind {
  /// The request timed out.
  timeout,

  /// A connection/socket error occurred.
  connection,

  /// The request was cancelled.
  cancel,

  /// A bad-response transport error (rare; prefer a [BoundaryResponse]).
  badResponse,

  /// A Firebase callable error carrying a [BoundaryError.code].
  callable,

  /// An otherwise unclassified transport failure.
  unknown,
}

/// A genuine transport failure or a callable error code.
///
/// This is *not* a non-2xx status code — those are [BoundaryResponse]s. Use a
/// [BoundaryError] to make an adapter raise a faithful native error (a dio
/// `DioException`, an http `ClientException`, or a real
/// `FirebaseFunctionsException`).
@immutable
final class BoundaryError {
  /// Creates a [BoundaryError].
  const BoundaryError({
    required this.kind,
    this.code,
    this.message,
    this.statusCode,
    this.body,
  });

  /// The failure category.
  final BoundaryErrorKind kind;

  /// A transport-specific code (e.g. callable `permission-denied`).
  final String? code;

  /// A human-readable message.
  final String? message;

  /// An optional status code associated with the failure.
  final int? statusCode;

  /// An optional payload associated with the failure.
  final Object? body;

  @override
  String toString() =>
      'BoundaryError(${kind.name}${code == null ? '' : ', $code'})';
}
