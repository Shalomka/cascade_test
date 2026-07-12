import 'package:cascade_core/cascade_core.dart';
import 'package:demo_dio_firebase/features/policies/policies_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/login_robot.dart';
import '../support/test_app.dart';

void main() {
  tearDown(resetHarnessConfig);

  testWidgets('AC2: an unstubbed call fails fast with method + full path', (
    tester,
  ) async {
    // No /policies stub is registered.
    final app = TestApp();
    await tester.pumpWidget(app.build());

    // The migrated login verb is a chain; terminate it with `.run()`. The rest
    // of this test keeps using the raw WidgetTesterX escape hatch (G7).
    await LoginRobot(tester).login().run();

    await tester.tapButton(PoliciesKeys.loadButton);
    await tester.pumpUntil(find.byKey(PoliciesKeys.error));

    final message = tester.widget<Text>(find.byKey(PoliciesKeys.error)).data!;
    expect(message, contains('GET'));
    expect(message, contains('/policies'));
  });
}
