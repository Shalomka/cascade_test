import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:demo_dio_firebase/features/messages/messages_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagesCubit', () {
    Future<Harness> buildSeededHarness({
      List<Map<String, dynamic>> messages = const [
        {'id': 'm1', 'text': 'hello'},
      ],
    }) {
      final builder = TestHarnessBuilder()
        ..useFirebase()
        ..withSignedInUser(uid: 'u1')
        ..withCollection('messages', messages);
      return builder.buildHarnessAsync();
    }

    MessagesCubit buildCubit(Harness harness) {
      final cubit = MessagesCubit(
        firestore: harness.firestore,
        auth: harness.auth,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test(
      'a seeded signed-in user renders the list with zero auth emissions '
      '(no-replay pin)',
      () async {
        final harness = await buildSeededHarness();
        // Drain the constructor's buffered sign-in event so the cubit is a
        // genuinely LATE authStateChanges() listener: it must rely on
        // auth.currentUser for its initial gate, not on a stream replay.
        final drain = harness.auth.authStateChanges().listen((_) {});
        await pumpEventQueue();
        await drain.cancel();

        final cubit = buildCubit(harness);

        expect(cubit.state.signedIn, isTrue, reason: 'gate from currentUser');
        await pumpEventQueue();
        expect(cubit.state.messages.map((m) => m.id), contains('m1'));
      },
    );

    test('a pushed document grows the live list', () async {
      final harness = await buildSeededHarness();
      final cubit = buildCubit(harness);
      await pumpEventQueue();

      await harness.pushDocument('messages/m2', {'text': 'second'});
      await pumpEventQueue();

      expect(
        cubit.state.messages.map((m) => m.id),
        containsAll(<String>['m1', 'm2']),
      );
    });

    test('a push into an empty collection renders the first row', () async {
      final harness = await buildSeededHarness(messages: const []);
      final cubit = buildCubit(harness);
      await pumpEventQueue();
      expect(cubit.state.signedIn, isTrue);
      expect(cubit.state.messages, isEmpty);

      final id = await harness.addToCollection('messages', {'text': 'first'});
      await pumpEventQueue();

      expect(cubit.state.messages.map((m) => m.id), contains(id));
    });

    test('sign-out gates the feature; re-sign-in restores the list', () async {
      final harness = await buildSeededHarness();
      final cubit = buildCubit(harness);
      await pumpEventQueue();
      expect(cubit.state.messages, isNotEmpty);

      await harness.emitSignOut();
      await pumpEventQueue();
      expect(cubit.state.signedIn, isFalse);
      expect(cubit.state.messages, isEmpty);

      await harness.emitSignIn(uid: 'u1');
      await pumpEventQueue();
      expect(cubit.state.signedIn, isTrue);
      expect(
        cubit.state.messages.map((m) => m.id),
        contains('m1'),
        reason: 're-sign-in resubscribes and re-renders the collection',
      );
    });

    test('close() cancels both subscriptions', () async {
      final harness = await buildSeededHarness();
      final cubit = MessagesCubit(
        firestore: harness.firestore,
        auth: harness.auth,
      );
      await pumpEventQueue();

      await cubit.close();

      // Neither a Firestore write nor an auth event may emit after close;
      // an un-cancelled subscription would throw (emit after close).
      await harness.pushDocument('messages/m9', {'text': 'late'});
      await harness.emitSignOut();
      await pumpEventQueue();
      expect(cubit.state.messages.map((m) => m.id), isNot(contains('m9')));
      expect(cubit.state.signedIn, isTrue);
    });
  });
}
