import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_dio_firebase/features/messages/messages_cubit.dart';
import 'package:demo_dio_firebase/features/messages/messages_keys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The messages section: a live `.snapshots()` list gated on Firebase auth.
class MessagesPage extends StatelessWidget {
  /// Creates a [MessagesPage] with its injected boundaries.
  const MessagesPage({required this.firestore, required this.auth, super.key});

  /// The injected Firestore boundary.
  final FirebaseFirestore firestore;

  /// The injected auth boundary.
  final FirebaseAuth auth;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MessagesCubit(firestore: firestore, auth: auth),
      child: BlocBuilder<MessagesCubit, MessagesState>(
        builder: (context, state) {
          if (!state.signedIn) {
            return const Text(
              'Sign in to see messages',
              key: MessagesKeys.signedOutPlaceholder,
            );
          }
          if (state.messages.isEmpty) {
            return const Text(
              'No messages yet',
              key: MessagesKeys.emptyState,
            );
          }
          return Column(
            key: MessagesKeys.list,
            children: [
              for (final message in state.messages)
                Text(message.text, key: MessagesKeys.row(message.id)),
            ],
          );
        },
      ),
    );
  }
}
