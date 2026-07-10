import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_http/src/registry_mock_client.dart';
import 'package:http/http.dart' as http;

/// Installs the `package:http` transport fake onto a [TestHarnessBuilder].
extension HttpInstaller on TestHarnessBuilder {
  /// Builds a registry-backed [http.Client] and exposes it via
  /// `Harness.httpClient` for injection into the app under test.
  void useHttpClient() {
    addInstallStep(
      (harness) => harness.put<http.Client>(registryMockClient(registry)),
    );
  }
}

/// Exposes the installed [http.Client] from the harness.
extension HttpHarness on Harness {
  /// The [http.Client] installed by [HttpInstaller.useHttpClient].
  http.Client get httpClient => get<http.Client>();
}
