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

    final login = LoginRobot(tester);
    final policies = TesterRobot(tester);
    final orders = OrdersRobot(tester);

    // The same cross-robot chain shape as the dio demo (minus profile), driving
    // the byte-identical LoginRobot/OrdersRobot and the same keys (AC3/C1).
    await login
        .login()
        .on(policies)
        .tap(PoliciesKeys.loadButton)
        .pumpUntilVisible(PoliciesKeys.result)
        .expectText(PoliciesKeys.result, 'Policies: 2')
        .on(orders)
        .submitOrder()
        .expectOrder('o1')
        .run();

    app
      ..expectCalledWith(
        '/orders',
        (body) => body is Map && body['sku'] == 'sku-123',
        method: 'POST',
      )
      ..expectCalled('/orders', method: 'POST', times: 2);
  });
}
