import 'package:cascade_core/cascade_core.dart';
import 'package:demo_dio_firebase/features/offers/offers_keys.dart';

/// Firebase-only offers robot (dio demo). Not part of the shared AC3 flow, so
/// it is NOT exported from `robots.dart` (the parity test byte-locks that
/// barrel); the acceptance test imports it directly — the profile_robot /
/// messages_robot precedent.
class OffersRobot extends Robot<OffersRobot> {
  /// Creates an [OffersRobot] driving [tester].
  OffersRobot(super.tester);

  /// Invokes the callable and waits for the read-back offer title to render.
  @useResult
  OffersRobot createOffer() =>
      tap(OffersKeys.createButton).pumpUntilVisible(OffersKeys.result);

  /// Asserts the read-back offer [title] is displayed.
  @useResult
  OffersRobot expectOffer(String title) =>
      expectText(OffersKeys.result, 'Offer: $title');
}
