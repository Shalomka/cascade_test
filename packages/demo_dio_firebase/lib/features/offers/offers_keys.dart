import 'package:flutter/widgets.dart';

/// Widget keys for the offers feature (R4.2). Firebase-only (dio demo).
abstract final class OffersKeys {
  /// The button that invokes the `createOffer` callable.
  static const createButton = Key('create_offer_button');

  /// The success result text (the offer title read back from Firestore).
  static const result = Key('offer_result');

  /// The failure/error text (the mapped callable error code).
  static const error = Key('offer_error');
}
