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

    // Log in via the shared robot; drive by keys only.
    await LoginRobot(tester).login();

    // GET /policies renders the seeded count.
    await tester.tapButton(PoliciesKeys.loadButton);
    await tester.pumpUntil(find.byKey(PoliciesKeys.result));
    await tester.expectText(PoliciesKeys.result, 'Policies: 2');

    // POST /orders returns 403 then 200 via the retry interceptor (R2.6).
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

    // Firestore-seeded profile + a callable error mapped above the facade (D4).
    final profile = ProfileRobot(tester);
    await profile.expectName('Ada');
    await profile.triggerCallable();
    await profile.expectError('permission-denied');
  });
}
