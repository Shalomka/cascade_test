import 'package:flutter/material.dart';

/// A minimal, app-agnostic [MaterialApp] wrapper for exercising the harness's
/// `WidgetTesterX` verbs in isolation (decoupled from any app's theming or
/// localization).
class MinimalApp extends StatelessWidget {
  /// Wraps [child] in a scaffolded [MaterialApp].
  const MinimalApp({required this.child, super.key});

  /// The widget under test.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }
}
