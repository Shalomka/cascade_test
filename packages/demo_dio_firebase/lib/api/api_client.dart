import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';

/// An application error mapped from a transport failure (the SUT for D4).
///
/// [message] preserves the underlying transport error's description so an
/// unstubbed call surfaces its method + path to the UI (AC2).
class ApiException implements Exception {
  /// Creates an [ApiException].
  ApiException(this.message, {this.statusCode});

  /// Maps a dio [error] into an [ApiException], preserving the root cause.
  factory ApiException.fromDio(DioException error) {
    final underlying = error.error;
    final detail = underlying?.toString() ?? error.message ?? error.toString();
    return ApiException(detail, statusCode: error.response?.statusCode);
  }

  /// A human-readable description of the failure.
  final String message;

  /// The HTTP status code, when the failure carried a response.
  final int? statusCode;

  @override
  String toString() => 'ApiException($message)';
}

/// A small real API client: serialization + error mapping (the SUT).
class ApiClient {
  /// Creates an [ApiClient] over [dio].
  ApiClient(this.dio);

  /// The dio instance carrying the app's real interceptors.
  final Dio dio;

  /// Fetches the policies list and returns its length.
  Future<int> fetchPoliciesCount() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/policies');
      final items = (response.data?['items'] as List?) ?? const [];
      return items.length;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Submits an order [body] and returns the created order id.
  Future<String> createOrder(Map<String, dynamic> body) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/orders',
        data: body,
      );
      return response.data?['id'] as String? ?? '';
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// A thin, app-owned facade over Firebase callable functions (A11/R6.2).
///
/// The app owns this interface so its production code stays free of the test
/// harness; the harness injects a registry-backed fake that implements it.
// ignore: one_member_abstracts
abstract class CallableClient {
  /// Invokes the callable [name] with optional [data].
  Future<T> call<T>(String name, {Object? data});
}

/// The production [CallableClient] wrapping a real [FirebaseFunctions].
class FirebaseCallableClient implements CallableClient {
  /// Creates a client backed by [functions].
  FirebaseCallableClient(this.functions);

  /// The Firebase Functions instance.
  final FirebaseFunctions functions;

  @override
  Future<T> call<T>(String name, {Object? data}) async {
    final result = await functions.httpsCallable(name).call<T>(data);
    return result.data;
  }
}
