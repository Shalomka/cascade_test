import 'package:flutter/widgets.dart';

/// Resolves whether [widget] is an enabled button.
///
/// Returns `true`/`false` when [widget] is a recognised button, or `null` when
/// this resolver does not handle the widget (so the next resolver runs).
typedef ButtonResolver = bool? Function(Widget widget);

/// Extracts display text from [widget], or `null` if it cannot.
typedef TextExtractor = String? Function(Widget widget);

/// Pluggable, app-specific hooks consulted by `WidgetTesterX` verbs (R4.4).
///
/// Registering resolvers/extractors lets a host app teach the harness about
/// its custom button and text widgets without the core knowing app types.
@immutable
final class HarnessConfig {
  /// Creates a [HarnessConfig].
  const HarnessConfig({
    this.buttonResolvers = const <ButtonResolver>[],
    this.textExtractors = const <TextExtractor>[],
    this.defaultLatency = const Duration(milliseconds: 100),
  });

  /// Resolvers consulted (in order) before the built-in button fallback.
  final List<ButtonResolver> buttonResolvers;

  /// Extractors consulted (in order) before the built-in text walk.
  final List<TextExtractor> textExtractors;

  /// The default per-stub latency the builder applies (R2.5).
  final Duration defaultLatency;
}

HarnessConfig _active = const HarnessConfig();

/// The currently active [HarnessConfig], read by `WidgetTesterX` verbs.
HarnessConfig get activeHarnessConfig => _active;

/// Sets the active [HarnessConfig] (call in `setUp`).
void configureHarness(HarnessConfig config) => _active = config;

/// Restores the default [HarnessConfig] (call in `tearDown`).
void resetHarnessConfig() => _active = const HarnessConfig();
