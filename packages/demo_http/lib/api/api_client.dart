import 'dart:convert';

import 'package:http/http.dart' as http;

/// An application error mapped from an HTTP response (the SUT).
class ApiException implements Exception {
  /// Creates an [ApiException].
  ApiException(this.message, {this.statusCode});

  /// A human-readable description of the failure.
  final String message;

  /// The HTTP status code, when available.
  final int? statusCode;

  @override
  String toString() => 'ApiException($message)';
}

/// A small real http-based API client: serialization + error mapping (SUT).
class ApiClient {
  /// Creates an [ApiClient] over [client].
  ApiClient(this.client, {this.baseUrl = 'https://api.demo'});

  /// The wrapped http client (with the app's real auth behavior).
  final http.Client client;

  /// The API base URL.
  final String baseUrl;

  /// Fetches the policies list and returns its length.
  Future<int> fetchPoliciesCount() async {
    final response = await client.get(Uri.parse('$baseUrl/policies'));
    if (response.statusCode >= 400) {
      throw ApiException(
        'GET /policies failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? const [];
    return items.length;
  }

  /// Submits an order [body], retrying once on 403 (mirrors the dio flow).
  Future<String> createOrder(Map<String, dynamic> body) async {
    var response = await _postOrder(body);
    if (response.statusCode == 403) {
      response = await _postOrder(body);
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        'POST /orders failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['id'] as String? ?? '';
  }

  Future<http.Response> _postOrder(Map<String, dynamic> body) {
    return client.post(
      Uri.parse('$baseUrl/orders'),
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json'},
    );
  }
}
