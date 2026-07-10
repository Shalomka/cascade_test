import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:demo_dio_firebase/features/orders/orders_cubit.dart';
import 'package:demo_dio_firebase/features/orders/orders_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The orders section: a POST screen exercising 403 → retry → 200 (AC1/R2.6).
class OrdersPage extends StatelessWidget {
  /// Creates an [OrdersPage] over [apiClient].
  const OrdersPage({required this.apiClient, super.key});

  /// The API client injected from the app root.
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersCubit(apiClient),
      child: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          return Column(
            children: [
              ElevatedButton(
                key: OrdersKeys.submitButton,
                onPressed: () => context.read<OrdersCubit>().submit(),
                child: const Text('Submit order'),
              ),
              if (state.status == OrdersStatus.success)
                Text('Order: ${state.orderId}', key: OrdersKeys.result),
              if (state.status == OrdersStatus.failure)
                Text(state.error, key: OrdersKeys.error),
            ],
          );
        },
      ),
    );
  }
}
