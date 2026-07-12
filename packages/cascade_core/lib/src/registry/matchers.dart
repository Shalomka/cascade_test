import 'package:cascade_core/src/registry/boundary_request.dart';

/// How a matcher compares its [RequestMatcher.endpoint] against a request.
enum EndpointMatch {
  /// The request endpoint must equal the matcher endpoint.
  exact,

  /// The request endpoint must start with the matcher endpoint.
  prefix,

  /// The matcher endpoint is a [RegExp] source the request must match.
  pattern,
}

/// A predicate deciding whether a [BoundaryRequest] should use a given stub.
///
/// The default is [RequestMatcher] (exact method + endpoint, with optional
/// query and body sub-matchers). Custom matchers may extend this class.
// ignore: one_member_abstracts
abstract class StubMatcher {
  /// Const base constructor for subclasses.
  const StubMatcher();

  /// Whether [request] is handled by the owning stub.
  bool matches(BoundaryRequest request);
}

/// The built-in matcher covering exact/prefix/pattern endpoint matching plus
/// optional query and body constraints (R2.4).
final class RequestMatcher extends StubMatcher {
  /// Matches [method] + [endpoint] exactly, with optional [query]/[body].
  const RequestMatcher(
    this.method,
    this.endpoint, {
    this.query,
    this.body,
  }) : endpointMatch = EndpointMatch.exact;

  /// Matches when the request endpoint starts with [endpoint].
  const RequestMatcher.prefix(
    this.method,
    this.endpoint, {
    this.query,
    this.body,
  }) : endpointMatch = EndpointMatch.prefix;

  /// Matches when the request endpoint matches the [endpoint] pattern.
  const RequestMatcher.pattern(
    this.method,
    this.endpoint, {
    this.query,
    this.body,
  }) : endpointMatch = EndpointMatch.pattern;

  /// The HTTP verb (or `CALL` for callables); compared case-insensitively.
  final String method;

  /// The endpoint literal, prefix, or [RegExp] source per [endpointMatch].
  final String endpoint;

  /// The endpoint comparison mode.
  final EndpointMatch endpointMatch;

  /// A required subset of query parameters, compared by string value.
  final Map<String, dynamic>? query;

  /// A predicate the decoded request body must satisfy.
  final bool Function(Object? body)? body;

  @override
  bool matches(BoundaryRequest request) {
    if (request.method.toUpperCase() != method.toUpperCase()) return false;
    final endpointOk = switch (endpointMatch) {
      EndpointMatch.exact => request.endpoint == endpoint,
      EndpointMatch.prefix => request.endpoint.startsWith(endpoint),
      EndpointMatch.pattern => RegExp(endpoint).hasMatch(request.endpoint),
    };
    if (!endpointOk) return false;
    final expectedQuery = query;
    if (expectedQuery != null) {
      for (final entry in expectedQuery.entries) {
        final actual = request.query[entry.key];
        if (actual?.toString() != entry.value?.toString()) return false;
      }
    }
    final bodyMatcher = body;
    if (bodyMatcher != null && !bodyMatcher(request.body)) return false;
    return true;
  }
}
