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
  void useDio(Dio dio) {
    dio.httpClientAdapter = FakeHttpClientAdapter(registry);
    addInstallStep((harness) => harness.put<Dio>(dio));
  }
}

/// Exposes the installed [Dio] from the harness.
extension DioHarness on Harness {
  /// The [Dio] installed by [DioInstaller.useDio].
  Dio get dio => get<Dio>();
}
