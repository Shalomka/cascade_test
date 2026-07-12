import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One rendered message row.
@immutable
class Message {
  /// Creates a [Message].
  const Message({required this.id, required this.text});

  /// The Firestore document id (drives the row key).
  final String id;

  /// The message text.
  final String text;
}

/// Immutable state for the messages feature.
@immutable
class MessagesState {
  /// Creates a [MessagesState].
  const MessagesState({this.signedIn = false, this.messages = const []});

  /// Whether a Firebase user is signed in (the feature's own gate).
  final bool signedIn;

  /// The live message rows, in snapshot order.
  final List<Message> messages;
}

/// A live-streaming cubit: renders the `messages` collection reactively and
/// gates on Firebase auth state.
///
/// The initial auth state is read from `auth.currentUser`, NOT from the
/// stream: `authStateChanges()` is a broadcast stream with no replay to late
/// listeners, so a stream-only gate would render signed-out forever.
class MessagesCubit extends Cubit<MessagesState> {
  /// Creates a [MessagesCubit] and subscribes to both streams.
  MessagesCubit({required this.firestore, required this.auth})
    : super(MessagesState(signedIn: auth.currentUser != null)) {
    _authSubscription = auth.authStateChanges().listen(_onAuthChanged);
    if (auth.currentUser != null) _subscribe();
  }

  /// The injected Firestore boundary.
  final FirebaseFirestore firestore;

  /// The injected auth boundary.
  final FirebaseAuth auth;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;

  void _onAuthChanged(User? user) {
    if (user == null) {
      unawaited(_messagesSubscription?.cancel());
      _messagesSubscription = null;
      emit(const MessagesState());
    } else {
      // A (re-)sign-in: resubscribe. The fake and the real SDK both emit the
      // current collection state to a new listener, so the list re-renders.
      emit(MessagesState(signedIn: true, messages: state.messages));
      _subscribe();
    }
  }

  void _subscribe() {
    _messagesSubscription ??= firestore
        .collection('messages')
        .snapshots()
        .listen(_onSnapshot);
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    emit(
      MessagesState(
        signedIn: true,
        messages: [
          for (final doc in snapshot.docs)
            Message(id: doc.id, text: (doc.data()['text'] as String?) ?? ''),
        ],
      ),
    );
  }

  @override
  Future<void> close() async {
    // Cancel both subscriptions or widget tests fail with leaked-async errors.
    await _authSubscription?.cancel();
    await _messagesSubscription?.cancel();
    return super.close();
  }
}
