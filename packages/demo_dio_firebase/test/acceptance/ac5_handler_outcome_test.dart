import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/login_robot.dart';
import '../robots/offers_robot.dart';
import '../support/test_app.dart';

void main() {
  tearDown(resetHarnessConfig);

  testWidgets('AC5: a handler outcome writes then reads its side-effect back', (
    tester,
  ) async {
    final app = TestApp()
      ..withSignedInUser(uid: 'u1')
      ..withCallableHandler('createOffer', (request, firestore) async {
        const id = 'offer-1'; // server-chosen id
        // MUST await so the write commits before the response is delivered.
        await firestore.doc('offers/$id').set({'title': 'Hello'});
        return {'offerId': id};
      });

    await tester.pumpWidget(app.build());

    final login = LoginRobot(tester);
    final offers = OffersRobot(tester);

    // The callable writes `offers/offer-1` server-side and returns its id; the
    // app reads the freshly-written doc back and renders its title. The write
    // commits on a later microtask, so we `pumpUntil` the title rather than
    // asserting synchronously against Firestore after the call (R2).
    await login.login().on(offers).createOffer().expectOffer('Hello').run();
  });
}
