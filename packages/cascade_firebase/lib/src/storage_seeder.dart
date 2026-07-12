import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';

/// A single object to seed into fake storage (R6.1).
class StorageObject {
  /// Seeds [contents] at the storage [path].
  const StorageObject(this.path, this.contents);

  /// The storage path (e.g. `avatars/u1.txt`).
  final String path;

  /// The string contents to store.
  final String contents;
}

/// Seeds [storage] with [objects] as initial state (R6.1).
Future<void> seedStorage(
  MockFirebaseStorage storage,
  List<StorageObject> objects,
) async {
  for (final object in objects) {
    await storage.ref(object.path).putString(object.contents);
  }
}
