import 'package:flutter/widgets.dart';

/// Widget keys for the orders feature (R4.2). Identical to the dio demo.
abstract final class OrdersKeys {
  /// The button that submits an order (POST).
  static const submitButton = Key('submit_order_button');

  /// The success result text.
  static const result = Key('order_result');

  /// The failure/error text.
  static const error = Key('order_error');
}
