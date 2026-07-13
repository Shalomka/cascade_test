import 'dart:convert';

import 'package:cascade_core/cascade_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds a `package:http` [http.Client] whose requests resolve against the
/// shared [StubRegistry] (R2.2).
///
/// A stubbed non-2xx status is returned as a real [http.Response]; the app's
/// production error mapping decides it is an error (the http analog of D4). A
/// [FailWith] outcome raises a genuine [http.ClientException].
http.Client registryMockClient(StubRegistry registry) {
  return MockClient((request) async {
    final boundaryRequest = _mapRequest(request);
    final resolved = registry.resolve(boundaryRequest);
    await Future<void>.delayed(resolved.latency);
    // A statement (not an expression) so the handler is awaited exactly once
    // before the response body is built (CR1-S2).
    switch (resolved.outcome) {
      case RespondWith(:final response):
        return _toResponse(response);
      case RespondWithHandler(:final handler):
        return _toResponse(await handler(boundaryRequest));
      case FailWith(:final error):
        throw http.ClientException(
          error.message ?? error.kind.name,
          request.url,
        );
    }
  });
}

http.Response _toResponse(BoundaryResponse response) {
  return http.Response(
    jsonEncode(response.body),
    response.statusCode,
    headers: {
      'content-type': 'application/json',
      ...response.headers,
    },
  );
}

BoundaryRequest _mapRequest(http.Request request) {
  Object? body;
  if (request.body.isNotEmpty) {
    try {
      body = jsonDecode(request.body);
    } on FormatException {
      body = request.body;
    }
  }
  return BoundaryRequest(
    kind: BoundaryKind.http,
    method: request.method,
    endpoint: request.url.path,
    body: body,
    query: Map<String, dynamic>.from(request.url.queryParameters),
    headers: request.headers,
  );
}
