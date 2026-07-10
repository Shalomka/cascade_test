import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_dio/src/fake_http_client_adapter.dart';
import 'package:dio/dio.dart';

/// Installs the dio transport fake onto a [TestHarnessBuilder].
extension DioInstaller on TestHarnessBuilder {
  /// Swaps [dio]'s adapter for a [FakeHttpClientAdapter] wired to the shared
  /// registry and exposes the same [dio] via `Harness.dio`.
  ///
  /// Inject this exact [dio] (with the app's real interceptors) into the app
  /// under test so every interceptor, serializer and error mapper runs.
  ///
  /// Side-effect-free until `buildHarness`: the adapter swap is deferred to the
  /// install step, matching `useHttpClient`/`useFirebase` and honoring R3.1's
  /// "no side effects until build()" contract.
  void useDio(Dio dio) {
    final registry = this.registry;
    addInstallStep((harness) {
      dio.httpClientAdapter = FakeHttpClientAdapter(registry);
      harness.put<Dio>(dio);
    });
  }
}

/// Exposes the installed [Dio] from the harness.
extension DioHarness on Harness {
  /// The [Dio] installed by [DioInstaller.useDio].
  Dio get dio => get<Dio>();
}
