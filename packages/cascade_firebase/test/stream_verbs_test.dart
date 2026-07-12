import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseStreamVerbs', () {
    late TestHarnessBuilder builder;

    setUp(() {
      builder = TestHarnessBuilder()..useFirebase();
    });

    group('pushDocument', () {
      test('a live snapshots() listener receives the pushed doc', () async {
        final harness = await builder.buildHarnessAsync();
        final snapshots = harness.firestore.collection('messages').snapshots();
        final counts = <int>[];
        final subscription = snapshots.listen(
          (snapshot) => counts.add(snapshot.docs.length),
        );
        addTearDown(subscription.cancel);

        await harness.pushDocument('messages/m1', {'text': 'hi'});
        await pumpEventQueue();

        expect(counts, contains(1));
        final doc = await harness.firestore.doc('messages/m1').get();
        expect(doc.data(), containsPair('text', 'hi'));
      });

      test('upserts an existing doc (set semantics)', () async {
        final harness = await builder.buildHarnessAsync();
        await harness.pushDocument('messages/m1', {'text': 'v1'});

        await harness.pushDocument('messages/m1', {'text': 'v2'});

        final doc = await harness.firestore.doc('messages/m1').get();
        expect(doc.data(), containsPair('text', 'v2'));
      });
    });

    group('updateDocument', () {
      test('updates an existing doc and the stream emits', () async {
        final harness = await builder.buildHarnessAsync();
        await harness.pushDocument('messages/m1', {'text': 'v1'});
        final emissions = <String?>[];
        final subscription = harness.firestore
            .doc('messages/m1')
            .snapshots()
            .listen(
              (snapshot) => emissions.add(snapshot.data()?['text'] as String?),
            );
        addTearDown(subscription.cancel);

        await harness.updateDocument('messages/m1', {'text': 'v2'});
        await pumpEventQueue();

        expect(emissions, contains('v2'));
      });

      test("propagates the fake's not-found error for a missing doc", () {
        final harness = builder.buildHarness();

        expect(
          () => harness.updateDocument('messages/missing', {'text': 'x'}),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'not-found',
            ),
          ),
        );
      });
    });

    group('deleteDocument', () {
      test('a live snapshots() listener receives the removal', () async {
        builder.withCollection('messages', [
          {'id': 'm1', 'text': 'hi'},
        ]);
        final harness = await builder.buildHarnessAsync();
        final counts = <int>[];
        final subscription = harness.firestore
            .collection('messages')
            .snapshots()
            .listen((snapshot) => counts.add(snapshot.docs.length));
        addTearDown(subscription.cancel);
        await pumpEventQueue();
        expect(counts, contains(1));

        await harness.deleteDocument('messages/m1');
        await pumpEventQueue();

        expect(counts.last, 0);
      });
    });

    group('addToCollection', () {
      test('returns the new id and the stream emits the row', () async {
        final harness = await builder.buildHarnessAsync();
        final ids = <List<String>>[];
        final subscription = harness.firestore
            .collection('messages')
            .snapshots()
            .listen(
              (snapshot) =>
                  ids.add(snapshot.docs.map((doc) => doc.id).toList()),
            );
        addTearDown(subscription.cancel);

        final id = await harness.addToCollection('messages', {'text': 'hi'});
        await pumpEventQueue();

        expect(id, isNotEmpty);
        expect(ids.last, contains(id));
      });
    });

    group('emitSignIn / emitSignOut', () {
      test('emitSignIn emits the user on authStateChanges()', () async {
        final harness = await builder.buildHarnessAsync();
        final emissions = <String?>[];
        final subscription = harness.auth.authStateChanges().listen(
          (user) => emissions.add(user?.uid),
        );
        addTearDown(subscription.cancel);

        await harness.emitSignIn(uid: 'u9', email: 'u9@example.com');
        await pumpEventQueue();

        expect(emissions, contains('u9'));
        expect(harness.auth.currentUser?.uid, 'u9');
      });

      test(
        'emitSignOut emits null, and a duplicate emits null again',
        () async {
          builder.withSignedInUser(uid: 'u1');
          final harness = await builder.buildHarnessAsync();
          final emissions = <String?>[];
          final subscription = harness.auth.authStateChanges().listen(
            (user) => emissions.add(user?.uid),
          );
          addTearDown(subscription.cancel);

          await harness.emitSignOut();
          await harness.emitSignOut();
          await pumpEventQueue();

          // The seeded sign-in ('u1') was added before any listener existed,
          // so the broadcast wrapper buffers it and delivers it first. Both
          // sign-outs then emit null — the fake does not de-duplicate.
          expect(emissions, containsAllInOrder(<String?>[null, null]));
          expect(harness.auth.currentUser, isNull);
        },
      );

      test('emitSignIn after emitSignOut is a fresh sign-in', () async {
        builder.withSignedInUser(uid: 'u1');
        final harness = await builder.buildHarnessAsync();
        final emissions = <String?>[];
        final subscription = harness.auth.authStateChanges().listen(
          (user) => emissions.add(user?.uid),
        );
        addTearDown(subscription.cancel);

        await harness.emitSignOut();
        await harness.emitSignIn(uid: 'u1');
        await pumpEventQueue();

        expect(emissions, containsAllInOrder(<String?>[null, 'u1']));
      });
    });

    group('whenReady ordering', () {
      test('verbs await pending install steps before writing', () async {
        var seedCommitted = false;
        builder.addInstallStep(
          (_) => Future<void>.delayed(
            const Duration(milliseconds: 50),
            () => seedCommitted = true,
          ),
        );
        // Build synchronously: the delayed step is still pending.
        final harness = builder.buildHarness();

        await harness.pushDocument('messages/m1', {'text': 'hi'});

        expect(
          seedCommitted,
          isTrue,
          reason: 'pushDocument must await whenReady before writing',
        );
      });
    });

    group('path validation', () {
      test('document verbs reject a collection-shaped path', () {
        final harness = builder.buildHarness();

        for (final (verb, call) in <(String, Future<void> Function())>[
          ('pushDocument', () => harness.pushDocument('messages', {})),
          ('updateDocument', () => harness.updateDocument('messages', {})),
          ('deleteDocument', () => harness.deleteDocument('messages')),
        ]) {
          expect(
            call,
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains(verb),
              ),
            ),
          );
        }
      });

      test('addToCollection rejects a document-shaped path', () {
        final harness = builder.buildHarness();

        expect(
          () => harness.addToCollection('messages/m1', {}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('addToCollection'),
            ),
          ),
        );
      });

      test('empty and malformed paths throw naming the verb', () {
        final harness = builder.buildHarness();

        expect(
          () => harness.pushDocument('', {}),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => harness.deleteDocument('messages//m1'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('deleteDocument'),
            ),
          ),
        );
      });
    });
  });
}
