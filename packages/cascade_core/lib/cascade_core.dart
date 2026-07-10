/// cascade_core: the app- and transport-agnostic core of the Flutter
/// acceptance-test harness (registry, builder, tester, robot, observability).
library;

export 'src/builder/harness_config.dart';
export 'src/builder/test_harness_builder.dart';
export 'src/builder/transport_installer.dart';
export 'src/observability/boundary_log.dart';
export 'src/observability/logging_observer.dart';
export 'src/registry/boundary_request.dart';
export 'src/registry/boundary_response.dart';
export 'src/registry/call_recorder.dart';
export 'src/registry/matchers.dart';
export 'src/registry/missing_stub_error.dart';
export 'src/registry/stub.dart';
export 'src/registry/stub_registry.dart';
export 'src/robot/robot.dart';
export 'src/tester/widget_tester_x.dart';
