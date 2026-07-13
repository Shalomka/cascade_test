import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseInstaller', () {
    test(
      'verbs wire to one shared registry and expose seeded fakes (R6.4)',
      () async {
        final builder = TestHarnessBuilder()
          ..withDefaultLatency(Duration.zero)
          ..useFirebase()
          ..withSignedInUser(uid: 'u1', email: 'ada@example.com')
          ..withCollection('users', [
            {'id': 'u1', 'name': 'Ada'},
          ])
          ..withDocument('config/app', {'flag': true})
          ..withStorageObject('avatars/u1.txt', 'hi')
          ..withCallable('createOrder', error: FunctionsError.permissionDenied);

        // buildHarnessAsync awaits seeding, so seeds are committed on return.
        final harness = await builder.buildHarnessAsync();

        // The callable stub was registered on the builder's shared registry.
        expect(builder.registry.stubs, isNotEmpty);

        // Auth is seeded as signed-in.
        expect(harness.auth.currentUser?.uid, 'u1');

        // Firestore collection + document seeds are readable immediately — no
        // drain/delay needed (I1).
        final user = await harness.firestore
            .collection('users')
            .doc('u1')
            .get();
        expect(user.data(), containsPair('name', 'Ada'));
        final config = await harness.firestore.doc('config/app').get();
        expect(config.data(), containsPair('flag', true));

        // The storage seed is committed too.
        expect(
          harness.storage.storedDataMap.containsKey('avatars/u1.txt'),
          isTrue,
        );

        // The callable flows through the same registry and throws a real error.
        await expectLater(
          harness.callableClient.call<void>('createOrder'),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      },
    );

    test(
      'withCallableHandler computes its body from the request and Firestore, '
      'writing then reading back (CR-1)',
      () async {
        final builder = TestHarnessBuilder()
          ..withDefaultLatency(Duration.zero)
          ..useFirebase()
          ..withCallableHandler('createOffer', (request, firestore) async {
            const id = 'offer-1';
            await firestore.doc('offers/$id').set({'title': 'Hello'});
            return {'offerId': id};
          });

        final harness = await builder.buildHarnessAsync();

        final result = await harness.callableClient.call<Map<String, dynamic>>(
          'createOffer',
        );
        expect(result, {'offerId': 'offer-1'});

        // The handler's write committed on the built fake Firestore.
        final doc = await harness.firestore.doc('offers/offer-1').get();
        expect(doc.data(), containsPair('title', 'Hello'));
      },
    );

    test(
      'withCallableHandler without useFirebase throws a descriptive '
      'StateError at the boundary (CR1-S5)',
      () async {
        final builder = TestHarnessBuilder()
          ..withDefaultLatency(Duration.zero)
          ..withCallableHandler(
            'createOffer',
            (request, firestore) async => <String, dynamic>{},
          )
          // Build WITHOUT useFirebase(): no FakeFirebaseFirestore is installed.
          ..buildHarness();

        // Assert at the boundary — the accessor's StateError surfaces directly,
        // not through the app (R3). It is a StateError, not a
        // FirebaseFunctionsException, so nothing swallows it.
        final client = FakeCallableClient(builder.registry);
        await expectLater(
          client.call<Map<String, dynamic>>('createOffer'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('No FakeFirebaseFirestore installed'),
            ),
          ),
        );
      },
    );

    test('withSignedOutUser seeds a signed-out auth', () {
      final builder = TestHarnessBuilder()
        ..useFirebase()
        ..withSignedOutUser();

      final harness = builder.buildHarness();

      expect(harness.auth.currentUser, isNull);
    });
  });
}
