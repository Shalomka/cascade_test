import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/src/auth_seeder.dart';
import 'package:cascade_firebase/src/firebase_installer.dart';

/// Post-build emit verbs that drive the live Firebase fakes.
///
/// The `withX` cascade verbs seed *initial* state; these verbs push *updates*
/// mid-test so live `.snapshots()` listeners and `authStateChanges()`
/// subscribers in the pumped app receive them. Every verb awaits
/// [Harness.whenReady] before touching the fake, so an emit can never
/// interleave with still-pending seed writes.
///
/// Writes commit on a later microtask: `await` the verb, then `pumpUntil`
/// (or `pumpUntilAbsent`) the UI change — never `pumpAndSettle`.
extension FirebaseStreamVerbs on Harness {
  /// Sets (upserts) the document at [path]; live snapshots emit.
  Future<void> pushDocument(String path, Map<String, dynamic> data) async {
    _requireDocumentPath('pushDocument', path);
    await whenReady;
    await firestore.doc(path).set(data);
  }

  /// Updates the existing document at [path]; throws the fake's not-found
  /// `FirebaseException` (mirroring real Firestore) when it does not exist.
  Future<void> updateDocument(String path, Map<String, dynamic> data) async {
    _requireDocumentPath('updateDocument', path);
    await whenReady;
    await firestore.doc(path).update(data);
  }

  /// Deletes the document at [path]; live snapshots emit the removal.
  Future<void> deleteDocument(String path) async {
    _requireDocumentPath('deleteDocument', path);
    await whenReady;
    await firestore.doc(path).delete();
  }

  /// Adds an auto-id document to the collection at [path].
  ///
  /// Returns the new document id so keys-only tests can await the row.
  Future<String> addToCollection(
    String path,
    Map<String, dynamic> data,
  ) async {
    _requireCollectionPath('addToCollection', path);
    await whenReady;
    final reference = await firestore.collection(path).add(data);
    return reference.id;
  }

  /// Signs in mid-test; `authStateChanges()` emits the new user.
  ///
  /// Emitting for an already-signed-in user is a fresh sign-in: [claims] are
  /// constructor-only on the mock user, so a mid-test claim change is
  /// expressed as a new `emitSignIn`.
  Future<void> emitSignIn({
    String uid = 'test-uid',
    String? email,
    Map<String, dynamic> claims = const {},
  }) async {
    await whenReady;
    auth.mockUser = buildMockUser(uid: uid, email: email, claims: claims);
    await auth.signInWithCredential(null);
  }

  /// Signs out mid-test; `authStateChanges()` emits null.
  ///
  /// A duplicate `emitSignOut()` emits null again (the fake does not
  /// de-duplicate), which subscribers must tolerate.
  Future<void> emitSignOut() async {
    await whenReady;
    await auth.signOut();
  }
}

/// Requires an even, non-empty segment count (a document path).
void _requireDocumentPath(String verb, String path) {
  if (_segments(verb, path).length.isOdd) {
    throw ArgumentError.value(
      path,
      'path',
      '$verb requires a document path (an even number of segments, '
          'e.g. "messages/m1")',
    );
  }
}

/// Requires an odd, non-empty segment count (a collection path).
void _requireCollectionPath(String verb, String path) {
  if (_segments(verb, path).length.isEven) {
    throw ArgumentError.value(
      path,
      'path',
      '$verb requires a collection path (an odd number of segments, '
          'e.g. "messages")',
    );
  }
}

List<String> _segments(String verb, String path) {
  final segments = path.split('/');
  if (path.isEmpty || segments.any((segment) => segment.isEmpty)) {
    throw ArgumentError.value(
      path,
      'path',
      '$verb requires a non-empty path with no empty segments',
    );
  }
  return segments;
}
