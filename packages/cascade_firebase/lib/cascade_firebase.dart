/// cascade_firebase: the Firebase transport adapter and seeders for the
/// cascade acceptance-test harness. Callables flow through the shared
/// registry; Firestore/Auth/Storage are stateful seeds.
library;

export 'src/auth_seeder.dart';
export 'src/callable_client.dart';
export 'src/firebase_installer.dart';
export 'src/firestore_seeder.dart';
export 'src/functions_error.dart';
export 'src/storage_seeder.dart';
