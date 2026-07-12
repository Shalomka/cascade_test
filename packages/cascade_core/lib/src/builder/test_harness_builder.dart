// Cascade verbs are intentionally methods, not setters, so the builder reads
// as a `..withX()` DSL (R3.1).
// ignore_for_file: use_setters_to_change_properties

import 'package:bloc/bloc.dart';
import 'package:cascade_core/src/builder/harness_config.dart';
import 'package:cascade_core/src/builder/transport_installer.dart';
import 'package:cascade_core/src/observability/boundary_log.dart';
import 'package:cascade_core/src/registry/boundary_response.dart';
import 'package:cascade_core/src/registry/matchers.dart';
import 'package:cascade_core/src/registry/stub.dart';
import 'package:cascade_core/src/registry/stub_registry.dart';
import 'package:meta/meta.dart';

/// A single stubbed HTTP response, used to program single stubs and sequences.
///
/// A shorthand over [BoundaryResponse] for the cascade surface, e.g.
/// `withPostSequence('/orders', [Res(403), Res(200, data: orderJson)])`.
@immutable
final class Res {
  /// Creates a response with [statusCode] and optional [data]/[latency].
  const Res(this.statusCode, {this.data, this.latency});

  /// The HTTP status code (may be non-2xx).
  final int statusCode;

  /// The decoded response body.
  final Object? data;

  /// An optional per-response latency override (R2.5).
  final Duration? latency;
}

/// The one cascade surface for configuring a full-system test (R3.1).
///
/// All mutators return `void` so `..` cascades read as the idiom and stay
/// side-effect-free until [buildHarness]. HTTP verbs and call-recording verbs
/// live here (transport-agnostic); adapter packages add their own verbs by
/// extension. Binding init, observer assignment and transport installation all
/// happen in [buildHarness] — a plain Dart method, never a widget `build`
/// (R3.2).
class TestHarnessBuilder {
  /// Creates an empty builder.
  TestHarnessBuilder();

  /// The one shared registry HTTP routes and callables resolve through.
  final StubRegistry registry = StubRegistry();

  final List<InstallStep> _installSteps = <InstallStep>[];
  BlocObserver? _observer;
  HarnessConfig? _config;
  bool _boundaryLog = false;
  Harness? _builtHarness;

  /// The harness returned by the last [buildHarness] call, so a test can drive
  /// post-build emit verbs (`app.harness.pushDocument(...)`) after pumping.
  ///
  /// Building again replaces it (last build wins), matching a re-pump. Throws
  /// a descriptive [StateError] when accessed before [buildHarness].
  Harness get harness {
    final built = _builtHarness;
    if (built == null) {
      throw StateError(
        'TestHarnessBuilder.harness accessed before build. '
        'Call buildHarness() (e.g. pumpWidget(app.build())) first.',
      );
    }
    return built;
  }

  // --- HTTP verbs (R2) -------------------------------------------------------

  /// Stubs a `GET` [path] returning [data] with [statusCode] (default 200).
  void withGet(
    String path, {
    Object? data,
    int statusCode = 200,
    Map<String, dynamic>? query,
    Duration? latency,
  }) {
    _registerHttp(
      'GET',
      path,
      [Res(statusCode, data: data, latency: latency)],
      query: query,
    );
  }

  /// Stubs a `POST` [path] returning [data] with [statusCode] (default 200).
  void withPost(
    String path, {
    Object? data,
    int statusCode = 200,
    Duration? latency,
  }) {
    _registerHttp('POST', path, [
      Res(statusCode, data: data, latency: latency),
    ]);
  }

  /// Stubs a `PUT` [path] returning [data] with [statusCode] (default 200).
  void withPut(
    String path, {
    Object? data,
    int statusCode = 200,
    Duration? latency,
  }) {
    _registerHttp('PUT', path, [Res(statusCode, data: data, latency: latency)]);
  }

  /// Stubs a `DELETE` [path] returning [data] with [statusCode].
  void withDelete(
    String path, {
    Object? data,
    int statusCode = 200,
    Duration? latency,
  }) {
    _registerHttp(
      'DELETE',
      path,
      [Res(statusCode, data: data, latency: latency)],
    );
  }

  /// Stubs a `GET` [path] whose successive calls return [responses] (R2.6).
  void withGetSequence(String path, List<Res> responses) =>
      _registerHttp('GET', path, responses);

  /// Stubs a `POST` [path] whose successive calls return [responses] (R2.6).
  void withPostSequence(String path, List<Res> responses) =>
      _registerHttp('POST', path, responses);

  /// Registers an arbitrary [stub] on the shared registry (escape hatch).
  void withStub(Stub stub) => registry.register(stub);

  void _registerHttp(
    String method,
    String path,
    List<Res> responses, {
    Map<String, dynamic>? query,
  }) {
    final outcomes = responses
        .map(
          (r) => RespondWith(
            BoundaryResponse(statusCode: r.statusCode, body: r.data),
            latency: r.latency,
          ),
        )
        .toList();
    registry.register(
      Stub(
        matcher: RequestMatcher(method, path, query: query),
        outcomes: outcomes,
      ),
    );
  }

  // --- Call-recording verbs (R2.7) ------------------------------------------

  /// Asserts [endpoint] was called (optionally by [method], [times] times).
  void expectCalled(String endpoint, {String? method, int? times}) =>
      registry.recorder.expectCalled(endpoint, method: method, times: times);

  /// Asserts [endpoint] was never called (optionally by [method]).
  void expectNeverCalled(String endpoint, {String? method}) =>
      registry.recorder.expectNeverCalled(endpoint, method: method);

  /// Asserts a call to [endpoint] had a body satisfying [bodyMatcher].
  void expectCalledWith(
    String endpoint,
    bool Function(Object? body) bodyMatcher, {
    String? method,
  }) =>
      registry.recorder.expectCalledWith(endpoint, bodyMatcher, method: method);

  // --- Observability (R7) ----------------------------------------------------

  /// Installs [observer] as `Bloc.observer` at build time (opt-in, no hijack).
  void withObserver(BlocObserver observer) => _observer = observer;

  /// Enables per-call boundary logging from the recorder (R7.1).
  void withBoundaryLog() => _boundaryLog = true;

  /// Sets the default per-stub latency (R2.5).
  void withDefaultLatency(Duration latency) =>
      registry.defaultLatency = latency;

  /// Applies a [HarnessConfig] read by the tester verbs (R4.4).
  void withConfig(HarnessConfig config) => _config = config;

  // --- Transport installation (AC3 seam) ------------------------------------

  /// Queues an [InstallStep] run against the [Harness] in [buildHarness].
  void addInstallStep(InstallStep step) => _installSteps.add(step);

  /// Runs [installer] against the harness at build time.
  void useInstaller(TransportInstaller installer) =>
      addInstallStep(installer.install);

  /// Performs all side effects and returns the populated [Harness].
  ///
  /// Initialises the test binding, installs the opt-in [BlocObserver] and
  /// [HarnessConfig], wires boundary logging, then runs every queued install
  /// step. This is deliberately a plain Dart method so nothing here runs inside
  /// a widget `build` (fixes the prior art's R3.2 violation).
  Harness buildHarness() {
    HarnessBinding.ensureInitialized();

    final observer = _observer;
    if (observer != null) Bloc.observer = observer;

    final config = _config;
    if (config != null) {
      configureHarness(config);
      registry.defaultLatency = config.defaultLatency;
    }

    if (_boundaryLog) registry.onResolved = logBoundaryCall;

    final harness = _builtHarness = Harness(registry);
    for (final step in _installSteps) {
      final result = step(harness);
      if (result is Future<void>) harness.registerPending(result);
    }
    return harness;
  }

  /// Builds the harness and awaits every async install step (e.g. Firebase
  /// seeding) so all seeded state is committed and any seeding error is
  /// surfaced before returning (R6.1).
  ///
  /// Prefer this over [buildHarness] whenever the test reads seeded transport
  /// state directly after building. The awaiting happens here in the async
  /// build path — never inside a widget `build` — so R3.1/R3.2 hold.
  Future<Harness> buildHarnessAsync() async {
    final harness = buildHarness();
    await harness.whenReady;
    return harness;
  }
}
