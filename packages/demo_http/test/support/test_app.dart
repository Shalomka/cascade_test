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

  /// Builds the real mirror app widget with the installed client injected.
  Widget build() {
    final harness = buildHarness();
    return App(httpClient: harness.httpClient);
  }
}
