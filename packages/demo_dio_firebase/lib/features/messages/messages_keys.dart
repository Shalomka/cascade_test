import 'package:flutter/widgets.dart';

/// Widget keys for the messages feature (R4.2).
///
/// Every asserted state has its own key: you cannot `pumpUntil` "nothing",
/// so empty, populated, and signed-out each render a keyed widget.
abstract final class MessagesKeys {
  /// The populated live list.
  static const list = Key('messages_list');

  /// The signed-in-but-empty placeholder.
  static const emptyState = Key('messages_empty');

  /// The signed-out placeholder (the feature's own auth gate).
  static const signedOutPlaceholder = Key('messages_signed_out');

  /// The row for the message with [id].
  static Key row(String id) => ValueKey('message_$id');
}
