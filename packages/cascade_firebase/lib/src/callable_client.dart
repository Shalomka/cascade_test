import 'package:cascade_core/cascade_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// A thin, app-owned transport facade over Firebase callable functions (R6.2).
///
/// The SDK's `FirebaseFunctions`/`HttpsCallableResult` have private
/// constructors and cannot be faked directly, so the app injects a
/// [CallableClient] instead. The facade returns raw decoded data or throws a
/// real [FirebaseFunctionsException] — the app's callable-error mapping lives
/// *above* the facade, exactly as `ApiClientException.fromDioError` lives above
/// dio's `HttpClientAdapter` (D4 preserved).
// ignore: one_member_abstracts
abstract class CallableClient {
  /// Invokes the callable [name] with optional [data] and returns its result.
  Future<T> call<T>(String name, {Object? data});
}

/// The production [CallableClient] wrapping a real [FirebaseFunctions].
class FirebaseCallableClient implements CallableClient {
  /// Creates a client backed by [functions].
  FirebaseCallableClient(this.functions);

  /// The Firebase Functions instance to call through.
  final FirebaseFunctions functions;

  @override
  Future<T> call<T>(String name, {Object? data}) async {
    final result = await functions.httpsCallable(name).call<T>(data);
    return result.data;
  }
}

/// A real [FirebaseFunctionsException] a callable stub can throw.
///
/// Subclassing is the supported way to construct the SDK exception from
/// outside its package; the app catches it as a [FirebaseFunctionsException].
class HarnessFunctionsException extends FirebaseFunctionsException {
  /// Creates an exception with [code], [message] and optional [details].
  HarnessFunctionsException({
    required super.code,
    required super.message,
    super.details,
  });
}

/// The harness [CallableClient] that resolves calls via the shared registry.
///
/// A [RespondWith] outcome returns the stubbed data; a [FailWith] outcome
/// throws a real [FirebaseFunctionsException] so the app's mapping runs (D4).
class FakeCallableClient implements CallableClient {
  /// Creates a fake bound to [registry].
  FakeCallableClient(this.registry);

  /// The shared registry callables resolve through.
  final StubRegistry registry;

  @override
  Future<T> call<T>(String name, {Object? data}) async {
    final request = BoundaryRequest(
      kind: BoundaryKind.callable,
      method: 'CALL',
      endpoint: name,
      body: data,
    );
    final resolved = registry.resolve(request);
    await Future<void>.delayed(resolved.latency);
    return switch (resolved.outcome) {
      RespondWith(:final response) => response.body as T,
      FailWith(:final error) => throw HarnessFunctionsException(
        code: error.code ?? 'unknown',
        message: error.message ?? 'Callable $name failed',
      ),
    };
  }
}
