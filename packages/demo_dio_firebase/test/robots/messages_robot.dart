import 'package:cascade_core/cascade_core.dart';
import 'package:demo_dio_firebase/features/messages/messages_keys.dart';

/// Firebase-only live-messages robot (dio demo). Not part of the shared AC3
/// flow, so it is NOT exported from `robots.dart` (the parity test byte-locks
/// that barrel); AC4 imports it directly — the profile_robot precedent.
class MessagesRobot extends Robot<MessagesRobot> {
  /// Creates a [MessagesRobot] driving [tester].
  MessagesRobot(super.tester);

  /// Asserts the row for the message [id] is visible.
  @useResult
  MessagesRobot expectRow(String id) => expectVisible(MessagesKeys.row(id));

  /// Waits until the row for the message [id] appears.
  @useResult
  MessagesRobot pumpUntilRow(String id) =>
      pumpUntilVisible(MessagesKeys.row(id));

  /// Waits until the row for the message [id] disappears.
  @useResult
  MessagesRobot pumpUntilRowGone(String id) =>
      pumpUntilGone(MessagesKeys.row(id));
}
