import 'package:bloc/bloc.dart';
import 'package:demo_http/api/api_client.dart';
import 'package:flutter/foundation.dart';

/// The lifecycle status of an order submission.
enum OrdersStatus {
  /// Nothing submitted yet.
  initial,

  /// A submission is in flight.
  loading,

  /// The submission succeeded.
  success,

  /// The submission failed.
  failure,
}

/// Immutable state for the orders feature.
@immutable
class OrdersState {
  /// Creates an [OrdersState].
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orderId = '',
    this.error = '',
  });

  /// The current lifecycle status.
  final OrdersStatus status;

  /// The created order id, when successful.
  final String orderId;

  /// The failure message, when failed.
  final String error;
}

/// A real cubit submitting an order through the http [ApiClient].
///
/// A single [submit] triggers the client's 403-retry, so against a `403, 200`
/// sequence the app records two POSTs and succeeds (mirrors the dio demo).
class OrdersCubit extends Cubit<OrdersState> {
  /// Creates an [OrdersCubit] over [apiClient].
  OrdersCubit(this.apiClient) : super(const OrdersState());

  /// The http-based API client (the SUT).
  final ApiClient apiClient;

  /// The order body submitted (asserted via `expectCalledWith`).
  static const Map<String, dynamic> orderBody = {'sku': 'sku-123', 'qty': 1};

  /// Submits [orderBody], mapping failures to [OrdersStatus.failure].
  Future<void> submit() async {
    emit(const OrdersState(status: OrdersStatus.loading));
    try {
      final id = await apiClient.createOrder(orderBody);
      emit(OrdersState(status: OrdersStatus.success, orderId: id));
    } on ApiException catch (error) {
      emit(OrdersState(status: OrdersStatus.failure, error: error.message));
    }
  }
}
