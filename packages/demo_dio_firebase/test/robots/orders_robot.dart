import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';

/// Shared orders flow robot. Byte-identical across the dio and http demos so
/// AC3 holds with zero robot change.
class OrdersRobot extends Robot<OrdersRobot> {
  /// Creates an [OrdersRobot] driving [tester].
  OrdersRobot(super.tester);

  /// The submit-order button key.
  static const submitButton = Key('submit_order_button');

  /// The order result text key.
  static const result = Key('order_result');

  /// Submits an order and waits for the result to appear.
  @useResult
  OrdersRobot submitOrder() => tap(submitButton).pumpUntilVisible(result);

  /// Asserts the created order [id] is displayed.
  @useResult
  OrdersRobot expectOrder(String id) => expectText(result, 'Order: $id');
}
