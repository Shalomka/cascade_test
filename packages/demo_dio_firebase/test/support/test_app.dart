import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_dio/cascade_dio.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:demo_dio_firebase/api/api_client.dart' as demo;
import 'package:demo_dio_firebase/app/app.dart';
import 'package:demo_dio_firebase/app/dio_factory.dart';
import 'package:flutter/widgets.dart';

/// Bridges the harness's registry-backed [CallableClient] to the demo's
/// app-owned facade so production code never depends on the harness.
class _BridgeCallableClient implements demo.CallableClient {
  _BridgeCallableClient(this._delegate);

  final CallableClient _delegate;

  @override
  Future<T> call<T>(String name, {Object? data}) =>
      _delegate.call<T>(name, data: data);
}

/// The Layer C test harness for the dio + Firebase demo.
///
/// Installs the dio and Firebase adapters against the one shared registry and
/// builds the real [App] with faked transport. Small by design (R1.1).
class TestApp extends TestHarnessBuilder {
  /// Wires the transports and a fast default latency.
  TestApp() {
    withDefaultLatency(const Duration(milliseconds: 5));
    useDio(createAppDio());
    useFirebase();
  }

  /// Builds the real app widget with the installed fakes injected.
  Widget build() {
    final harness = buildHarness();
    return App(
      dio: harness.dio,
      firestore: harness.firestore,
      auth: harness.auth,
      callableClient: _BridgeCallableClient(harness.callableClient),
    );
  }
}
