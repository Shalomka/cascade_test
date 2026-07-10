/// The canonical Cloud Functions error codes a callable stub can raise.
///
/// Maps to the string `code` carried by a `FirebaseFunctionsException`, so the
/// app's real callable-error mapping (which sits above the facade) runs (D4).
enum FunctionsError {
  /// The operation was cancelled.
  cancelled('cancelled'),

  /// The client specified an invalid argument.
  invalidArgument('invalid-argument'),

  /// A requested document/resource was not found.
  notFound('not-found'),

  /// The caller does not have permission (the AC1 callable scenario).
  permissionDenied('permission-denied'),

  /// The request was not authenticated.
  unauthenticated('unauthenticated'),

  /// The service is currently unavailable.
  unavailable('unavailable'),

  /// An internal error occurred.
  internal('internal'),

  /// An unknown error occurred.
  unknown('unknown');

  const FunctionsError(this.code);

  /// The Cloud Functions string code for this error.
  final String code;
}
