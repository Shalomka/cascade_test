import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// A collection of documents to seed into a fake Firestore (R6.1).
class CollectionSeed {
  /// Seeds [documents] into the collection at [path].
  const CollectionSeed(this.path, this.documents);

  /// The collection path (e.g. `users`).
  final String path;

  /// The documents; an `id` field, if present, becomes the document id.
  final List<Map<String, dynamic>> documents;
}

/// A single document to seed at an explicit path (R6.1).
class DocumentSeed {
  /// Seeds [data] at the document [path].
  const DocumentSeed(this.path, this.data);

  /// The document path (e.g. `users/u1`).
  final String path;

  /// The document data.
  final Map<String, dynamic> data;
}

/// Seeds [firestore] with [collections] and [documents] as initial state.
///
/// Seeds are *initial state*, not stubbed calls: reading an unseeded
/// collection legitimately returns empty and does not fail fast (R6.1).
Future<void> seedFirestore(
  FakeFirebaseFirestore firestore, {
  List<CollectionSeed> collections = const [],
  List<DocumentSeed> documents = const [],
}) async {
  for (final seed in collections) {
    final collection = firestore.collection(seed.path);
    for (final data in seed.documents) {
      final id = data['id'];
      if (id is String) {
        await collection.doc(id).set(data);
      } else {
        await collection.add(data);
      }
    }
  }
  for (final seed in documents) {
    await firestore.doc(seed.path).set(seed.data);
  }
}
