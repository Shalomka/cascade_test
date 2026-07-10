import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:demo_dio_firebase/app/app.dart';
import 'package:demo_dio_firebase/app/dio_factory.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// The production entrypoint wiring the real Firebase and dio boundaries.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    App(
      dio: createAppDio(),
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
      callableClient: FirebaseCallableClient(FirebaseFunctions.instance),
    ),
  );
}
