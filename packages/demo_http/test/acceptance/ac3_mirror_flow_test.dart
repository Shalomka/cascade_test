import 'package:cascade_core/cascade_core.dart';
import 'package:demo_http/features/policies/policies_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/login_robot.dart';
import '../robots/orders_robot.dart';
import '../support/fixtures.dart';
import '../support/test_app.dart';

void main() {
  tearDown(resetHarnessConfig);

  testWidgets('AC3: mirror http flow via the same robots and keys', (
    tester,
  ) async {
    final app = TestApp()
      ..withGet('/policies', data: Fixtures.policies)
      ..withPostSequence('/orders', const [
        Res(403),
        Res(200, data: {'id': 'o1'}),
      ]);

    await tester.pumpWidget(app.build());

    // The exact same LoginRobot as the dio demo.
    await LoginRobot(tester).login();

    await tester.tapButton(PoliciesKeys.loadButton);
    await tester.pumpUntil(find.byKey(PoliciesKeys.result));
    await tester.expectText(PoliciesKeys.result, 'Policies: 2');

    final orders = OrdersRobot(tester);
    await orders.submitOrder();
    await orders.expectOrder('o1');

    app
      ..expectCalledWith(
        '/orders',
        (body) => body is Map && body['sku'] == 'sku-123',
        method: 'POST',
      )
      ..expectCalled('/orders', method: 'POST', times: 2);
  });
}
