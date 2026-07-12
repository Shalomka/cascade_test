import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:demo_dio_firebase/features/policies/policies_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/login_robot.dart';
import '../robots/orders_robot.dart';
import '../robots/profile_robot.dart';
import '../support/fixtures.dart';
import '../support/test_app.dart';

void main() {
  tearDown(resetHarnessConfig);

  testWidgets('AC1: full dio + Firebase acceptance flow', (tester) async {
    final app = TestApp()
      ..withSignedInUser(uid: 'u1')
      ..withCollection('users', [Fixtures.user])
      ..withGet('/policies', data: Fixtures.policies)
      ..withPostSequence('/orders', const [
        Res(403),
        Res(200, data: {'id': 'o1'}),
      ])
      ..withCallable('createOrder', error: FunctionsError.permissionDenied);

    await tester.pumpWidget(app.build());

    final login = LoginRobot(tester);
    final policies = TesterRobot(tester);
    final orders = OrdersRobot(tester);
    final profile = ProfileRobot(tester);

    // The whole flow reads as one cross-robot chain, hopping robots with
    // `.on()` on a single shared queue, drained once by `.run()` (C1):
    //   login → policies (raw tester verbs) → orders → profile.
    await login
        .login()
        .on(policies)
        // GET /policies renders the seeded count. The policies step joins the
        // chain via TesterRobot instead of raw eager `tester.*` (C2).
        .tap(PoliciesKeys.loadButton)
        .pumpUntilVisible(PoliciesKeys.result)
        .expectText(PoliciesKeys.result, 'Policies: 2')
        // POST /orders returns 403 then 200 via the retry interceptor (R2.6).
        .on(orders)
        .submitOrder()
        .expectOrder('o1')
        // Firestore-seeded profile + a callable error mapped above the facade.
        .on(profile)
        .expectName('Ada')
        .triggerCallable()
        .expectError('permission-denied')
        .run();

    // Eager registry assertions run AFTER the drain so they observe the
    // chain's effects (composition rule for eager assertions, R7/flow-gap #6).
    app
      ..expectCalledWith(
        '/orders',
        (body) => body is Map && body['sku'] == 'sku-123',
        method: 'POST',
      )
      ..expectCalled('/orders', method: 'POST', times: 2);
  });
}
