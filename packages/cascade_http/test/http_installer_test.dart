import 'dart:convert';

import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_http/cascade_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('HttpInstaller', () {
    test(
      'useHttpClient exposes a registry-backed client via the harness',
      () async {
        final builder = TestHarnessBuilder()
          ..withDefaultLatency(Duration.zero)
          ..useHttpClient()
          ..withGet('/policies', data: {'ok': true});

        final harness = builder.buildHarness();
        final client = harness.httpClient;

        expect(client, isA<http.Client>());

        final response = await client.get(
          Uri.parse('https://api.test/policies'),
        );
        expect(jsonDecode(response.body), {'ok': true});
      },
    );
  });
}
