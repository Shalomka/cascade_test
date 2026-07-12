import 'dart:async';

import 'package:cascade_core/src/registry/stub_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A configuration step run against the [Harness] at build time.
///
/// A step may be synchronous (adapter installation) or asynchronous (e.g.
/// Firestore/Storage seeding). Async steps return a [Future]; the builder
/// tracks it via [Harness.registerPending] so callers can await all seeding
/// through `buildHarnessAsync`.
typedef InstallStep = FutureOr<void> Function(Harness harness);

/// The container that exposes the shared [StubRegistry] and the transport
/// fakes installed by adapter packages.
///
/// Adapters store their installed objects with [put] and surface typed getters
/// via extensions (`Harness.dio`, `Harness.httpClient`, `Harness.firestore`,
/// ...). This bag is the seam that makes AC3 (swap adapter, zero test change)
/// hold: the test only ever talks to the registry and the demo's own keys.
final class Harness {
  /// Creates a [Harness] bound to [registry].
  Harness(this.registry);

  /// The one shared registry every transport resolves through.
  final StubRegistry registry;

  final Map<Type, Object> _installed = <Type, Object>{};

  final List<Future<void>> _pending = <Future<void>>[];

  /// Registers a [future] that must complete before the harness's seeded state
  /// (Firestore/Storage) is guaranteed committed.
  ///
  /// Called by the builder for every async install step; awaited together via
  /// [whenReady]. Registering (rather than swallowing) the future ensures seed
  /// errors surface instead of being silently dropped.
  void registerPending(Future<void> future) => _pending.add(future);

  /// Completes once every async install step has finished, so all seeded state
  /// is present and any seeding error is propagated (R6.1).
  Future<void> get whenReady => Future.wait(_pending);

  /// Stores an installed transport object keyed by its type.
  void put<T extends Object>(T value) => _installed[T] = value;

  /// Returns the installed object of type [T].
  ///
  /// Throws [StateError] when nothing of type [T] was installed.
  T get<T extends Object>() {
    final value = _installed[T];
    if (value == null) {
      throw StateError(
        'No $T installed on the harness. Call the matching use*/with* verb '
        'before build().',
      );
    }
    return value as T;
  }

  /// Returns the installed object of type [T], or `null` if absent.
  T? maybe<T extends Object>() => _installed[T] as T?;

  /// Whether an object of type [T] has been installed.
  bool has<T extends Object>() => _installed.containsKey(T);
}

/// An object-oriented seam for installing a transport fake onto the harness.
///
/// Adapter packages usually expose ergonomic `use*` extension methods, but a
/// [TransportInstaller] is the explicit contract those helpers fulfil and is
/// handy for composing installers. It runs against the [Harness] at build
/// time and reads the shared registry via [Harness.registry].
// ignore: one_member_abstracts
abstract class TransportInstaller {
  /// Const base constructor.
  const TransportInstaller();

  /// Installs this transport's fake onto [harness].
  void install(Harness harness);
}

/// Centralises Flutter test-binding initialisation (R3.2).
///
/// Called from `TestHarnessBuilder.buildHarness` — never from a widget
/// `build` method — so binding init happens in plain Dart code.
abstract final class HarnessBinding {
  /// Ensures the test binding is initialised and returns it.
  static WidgetsBinding ensureInitialized() =>
      TestWidgetsFlutterBinding.ensureInitialized();
}
