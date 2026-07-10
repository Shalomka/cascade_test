import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared orders flow robot. Byte-identical across the dio and http demos so
/// AC3 holds with zero robot change.
class OrdersRobot extends Robot {
  /// Creates an [OrdersRobot] driving [tester].
  OrdersRobot(super.tester);

  /// The submit-order button key.
  static const submitButton = Key('submit_order_button');

  /// The order result text key.
  static const result = Key('order_result');

  /// Submits an order and waits for the result to appear.
  Future<void> submitOrder() async {
    await tester.tapButton(submitButton);
    await tester.pumpUntil(find.byKey(result));
  }

  /// Asserts the created order [id] is displayed.
  Future<void> expectOrder(String id) =>
      tester.expectText(result, 'Order: $id');
}
