import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Immutable state for the profile feature.
@immutable
class ProfileState {
  /// Creates a [ProfileState].
  const ProfileState({this.name = '', this.error = ''});

  /// The seeded user's display name (from Firestore).
  final String name;

  /// The mapped callable error code, when the callable fails.
  final String error;
}

/// A real cubit reading seeded Firestore state and invoking a callable.
///
/// The callable-error mapping lives here, *above* the [CallableClient] facade
/// (D4): the facade throws a real [FirebaseFunctionsException] and this cubit
/// maps its `code`.
class ProfileCubit extends Cubit<ProfileState> {
  /// Creates a [ProfileCubit] with its injected boundaries.
  ProfileCubit({
    required this.firestore,
    required this.auth,
    required this.callableClient,
  }) : super(const ProfileState());

  /// The injected Firestore boundary.
  final FirebaseFirestore firestore;

  /// The injected auth boundary.
  final FirebaseAuth auth;

  /// The injected callable facade.
  final CallableClient callableClient;

  /// Loads the signed-in user's profile document from Firestore.
  Future<void> load() async {
    final uid = auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final doc = await firestore.collection('users').doc(uid).get();
    final name = (doc.data()?['name'] as String?) ?? '';
    emit(ProfileState(name: name));
  }

  /// Invokes the `createOrder` callable and maps any error code (D4).
  Future<void> createOrder() async {
    try {
      await callableClient.call<void>('createOrder');
    } on FirebaseFunctionsException catch (error) {
      emit(ProfileState(name: state.name, error: error.code));
    }
  }
}
