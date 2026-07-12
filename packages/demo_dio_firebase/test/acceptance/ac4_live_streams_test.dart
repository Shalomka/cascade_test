import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:demo_dio_firebase/app/app.dart';
import 'package:demo_dio_firebase/features/messages/messages_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/login_robot.dart';
import '../robots/messages_robot.dart';
import '../support/fixtures.dart';
import '../support/test_app.dart';

void main() {
  tearDown(resetHarnessConfig);

  testWidgets('AC4: live Firebase streams drive the pumped UI', (
    tester,
  ) async {
    final app = TestApp()
      ..withSignedInUser(uid: 'u1')
      ..withCollection('messages', Fixtures.messages);

    await tester.pumpWidget(app.build());

    final login = LoginRobot(tester);
    final messages = MessagesRobot(tester);

    // Chain 1: through the local login gate, the seeded rows render live.
    // The snapshot lands on a later microtask, so wait for the first row
    // (never assert straight after an emit); m2 arrives in the same snapshot.
    await login.login().on(messages).pumpUntilRow('m1').expectRow('m2').run();

    // Mid-test push — the awaited verb returns the new id (keys-only, AC-S1a).
    final id = await app.harness.addToCollection('messages', {'text': 'hi'});

    // Chain 2: list grows, delete emits the removal, sign-out gates the
    // feature (the LoginCubit gate is untouched), re-sign-in restores it.
    await messages
        .pumpUntilRow(id)
        .expectRow(id)
        .step(
          'deleteDocument(messages/m1)',
          () => app.harness.deleteDocument('messages/m1'),
        )
        .pumpUntilRowGone('m1')
        .step('emitSignOut', () => app.harness.emitSignOut())
        .pumpUntilVisible(MessagesKeys.signedOutPlaceholder)
        .expectVisible(AppKeys.homePage)
        .step('emitSignIn(u1)', () => app.harness.emitSignIn(uid: 'u1'))
        .pumpUntilRow('m2')
        .run();
  });
}
