import 'package:flutter/widgets.dart';

/// Widget keys for the profile feature (R4.2). Firebase-only (dio demo).
abstract final class ProfileKeys {
  /// The seeded Firestore user name text.
  static const name = Key('profile_name');

  /// The button that invokes the `createOrder` callable.
  static const callableButton = Key('create_order_callable_button');

  /// The callable-error text (shows the mapped error code).
  static const error = Key('profile_error');
}
