import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_http/cascade_http.dart';
import 'package:demo_http/app/app.dart';
import 'package:flutter/widgets.dart';

/// The Layer C test harness for the http mirror demo.
///
/// Installs only the http adapter against the shared registry and builds the
/// real mirror [App] with faked transport. Same shape as the dio demo's
/// `TestApp`, differing only in the installer (AC3).
class TestApp extends TestHarnessBuilder {
  /// Wires the http transport and a fast default latency.
  TestApp() {
    withDefaultLatency(const Duration(milliseconds: 5));
    useHttpClient();
  }

  Harness? _harness;

  /// The harness built by [build], for post-build emit verbs.
  ///
  /// Calling [build] again replaces it (last build wins), matching a re-pump.
  /// Throws a descriptive [StateError] when accessed before [build].
  Harness get harness {
    final built = _harness;
    if (built == null) {
      throw StateError(
        'TestApp.harness accessed before build(). '
        'Call pumpWidget(app.build()) first.',
      );
    }
    return built;
  }

  /// Builds the real mirror app widget with the installed client injected.
  Widget build() {
    final harness = _harness = buildHarness();
    return App(httpClient: harness.httpClient);
  }
}
