import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:demo_dio_firebase/features/profile/profile_cubit.dart';
import 'package:demo_dio_firebase/features/profile/profile_keys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The profile section: renders seeded Firestore state and a callable error.
class ProfilePage extends StatelessWidget {
  /// Creates a [ProfilePage] with its injected boundaries.
  const ProfilePage({
    required this.firestore,
    required this.auth,
    required this.callableClient,
    super.key,
  });

  /// The injected Firestore boundary.
  final FirebaseFirestore firestore;

  /// The injected auth boundary.
  final FirebaseAuth auth;

  /// The injected callable facade.
  final CallableClient callableClient;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = ProfileCubit(
          firestore: firestore,
          auth: auth,
          callableClient: callableClient,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return Column(
            children: [
              Text(state.name, key: ProfileKeys.name),
              ElevatedButton(
                key: ProfileKeys.callableButton,
                onPressed: () => context.read<ProfileCubit>().createOrder(),
                child: const Text('Create order (callable)'),
              ),
              if (state.error.isNotEmpty)
                Text(state.error, key: ProfileKeys.error),
            ],
          );
        },
      ),
    );
  }
}
