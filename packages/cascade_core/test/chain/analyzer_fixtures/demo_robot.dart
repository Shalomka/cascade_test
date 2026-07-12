import 'package:cascade_core/cascade_core.dart';

/// A minimal concrete robot used only by the analyzer fixtures. It is never
/// constructed at runtime — the fixtures accept it as a parameter so the
/// analyzer can reason about verb misuse statically.
class DemoRobot extends Robot<DemoRobot> {
  DemoRobot(super.tester);
}
