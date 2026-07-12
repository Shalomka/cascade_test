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
    final resolved = registry.resolve(_mapRequest(request));
    await Future<void>.delayed(resolved.latency);
    return switch (resolved.outcome) {
      RespondWith(:final response) => http.Response(
        jsonEncode(response.body),
        response.statusCode,
        headers: {
          'content-type': 'application/json',
          ...response.headers,
        },
      ),
      FailWith(:final error) => throw http.ClientException(
        error.message ?? error.kind.name,
        request.url,
      ),
    };
  });
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
