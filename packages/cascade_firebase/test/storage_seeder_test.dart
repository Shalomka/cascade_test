import 'dart:convert';

import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seedStorage', () {
    test('stores objects readable back through the ref (R6.1)', () async {
      final storage = MockFirebaseStorage();

      await seedStorage(storage, const [
        StorageObject('avatars/u1.txt', 'hello'),
      ]);

      final bytes = await storage.ref('avatars/u1.txt').getData();
      expect(bytes, isNotNull);
      expect(utf8.decode(bytes!), 'hello');
    });
  });
}
