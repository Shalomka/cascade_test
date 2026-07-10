import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seedFirestore', () {
    test('seeds collections by id and explicit documents', () async {
      final firestore = FakeFirebaseFirestore();

      await seedFirestore(
        firestore,
        collections: const [
          CollectionSeed('users', [
            {'id': 'u1', 'name': 'Ada'},
          ]),
        ],
        documents: const [
          DocumentSeed('config/app', {'flag': true}),
        ],
      );

      final user = await firestore.collection('users').doc('u1').get();
      expect(user.data(), containsPair('name', 'Ada'));

      final config = await firestore.doc('config/app').get();
      expect(config.data(), containsPair('flag', true));
    });

    test('adds documents that lack an id field', () async {
      final firestore = FakeFirebaseFirestore();

      await seedFirestore(
        firestore,
        collections: const [
          CollectionSeed('logs', [
            {'message': 'hello'},
          ]),
        ],
      );

      final snapshot = await firestore.collection('logs').get();
      expect(snapshot.docs, hasLength(1));
    });

    test(
      'an unseeded collection reads empty and does not fail (R6.1)',
      () async {
        final firestore = FakeFirebaseFirestore();

        final snapshot = await firestore.collection('orders').get();

        expect(snapshot.docs, isEmpty);
      },
    );
  });
}
