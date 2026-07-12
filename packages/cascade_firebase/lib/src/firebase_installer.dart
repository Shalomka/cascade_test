import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/src/auth_seeder.dart';
import 'package:cascade_firebase/src/callable_client.dart';
import 'package:cascade_firebase/src/firestore_seeder.dart';
import 'package:cascade_firebase/src/functions_error.dart';
import 'package:cascade_firebase/src/storage_seeder.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';

/// Accumulates Firebase seed specs across cascade verbs, keyed per builder.
class _FirebaseConfig {
  final List<CollectionSeed> collections = [];
  final List<DocumentSeed> documents = [];
  final List<StorageObject> storageObjects = [];
  bool signedIn = false;
  MockUser? user;
}

final Expando<_FirebaseConfig> _configs = Expando<_FirebaseConfig>();

/// Installs the Firebase transport fakes and seed verbs onto a builder (R6).
extension FirebaseInstaller on TestHarnessBuilder {
  _FirebaseConfig get _config => _configs[this] ??= _FirebaseConfig();

  /// Installs `FakeFirebaseFirestore`, `MockFirebaseAuth`,
  /// `MockFirebaseStorage` and a [FakeCallableClient], applying all queued
  /// seeds at build time (R3.2). Exposes them via the `Harness` getters.
  void useFirebase() {
    final config = _config;
    addInstallStep((harness) async {
      final firestore = FakeFirebaseFirestore();
      final auth = buildMockAuth(signedIn: config.signedIn, user: config.user);
      final storage = MockFirebaseStorage();

      harness
        ..put<FakeFirebaseFirestore>(firestore)
        ..put<MockFirebaseAuth>(auth)
        ..put<MockFirebaseStorage>(storage)
        ..put<CallableClient>(FakeCallableClient(harness.registry));

      // Awaited so the seeds are committed before `buildHarnessAsync` returns
      // and so any seeding error surfaces instead of being swallowed (I1).
      await seedFirestore(
        firestore,
        collections: config.collections,
        documents: config.documents,
      );
      await seedStorage(storage, config.storageObjects);
    });
  }

  /// Stubs the callable [name] to return [data], or to throw a real
  /// `FirebaseFunctionsException` carrying [error] (R6.2). Flows through the
  /// same shared registry as HTTP routes.
  void withCallable(String name, {Object? data, FunctionsError? error}) {
    final outcome = error != null
        ? FailWith(
            BoundaryError(
              kind: BoundaryErrorKind.callable,
              code: error.code,
              message: 'Callable $name failed with ${error.code}',
            ),
          )
        : RespondWith(BoundaryResponse(statusCode: 200, body: data));
    registry.register(
      Stub(matcher: RequestMatcher('CALL', name), outcomes: [outcome]),
    );
  }

  /// Seeds the Firestore collection at [path] with [documents] (R6.1).
  void withCollection(String path, List<Map<String, dynamic>> documents) =>
      _config.collections.add(CollectionSeed(path, documents));

  /// Seeds a single Firestore document at [path] with [data] (R6.1).
  void withDocument(String path, Map<String, dynamic> data) =>
      _config.documents.add(DocumentSeed(path, data));

  /// Seeds a storage object at [path] with string [contents] (R6.1).
  void withStorageObject(String path, String contents) =>
      _config.storageObjects.add(StorageObject(path, contents));

  /// Seeds a signed-in user with [uid], optional [email] and [claims] (R6.1).
  void withSignedInUser({
    String uid = 'test-uid',
    String? email,
    Map<String, dynamic> claims = const {},
  }) {
    _config
      ..signedIn = true
      ..user = buildMockUser(uid: uid, email: email, claims: claims);
  }

  /// Seeds a signed-out auth state (R6.1).
  void withSignedOutUser() {
    _config
      ..signedIn = false
      ..user = null;
  }
}

/// Exposes the installed Firebase fakes from the harness.
extension FirebaseHarness on Harness {
  /// The installed fake Firestore.
  FakeFirebaseFirestore get firestore => get<FakeFirebaseFirestore>();

  /// The installed mock Auth.
  MockFirebaseAuth get auth => get<MockFirebaseAuth>();

  /// The installed mock Storage.
  MockFirebaseStorage get storage => get<MockFirebaseStorage>();

  /// The installed fake callable client.
  CallableClient get callableClient => get<CallableClient>();
}
