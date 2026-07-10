import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:demo_dio_firebase/features/policies/policies_cubit.dart';
import 'package:demo_dio_firebase/features/policies/policies_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The policies section: a GET screen (AC1) that also proves AC2 fail-fast.
class PoliciesPage extends StatelessWidget {
  /// Creates a [PoliciesPage] over [apiClient].
  const PoliciesPage({required this.apiClient, super.key});

  /// The API client injected from the app root.
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PoliciesCubit(apiClient),
      child: BlocBuilder<PoliciesCubit, PoliciesState>(
        builder: (context, state) {
          return Column(
            children: [
              ElevatedButton(
                key: PoliciesKeys.loadButton,
                onPressed: () => context.read<PoliciesCubit>().load(),
                child: const Text('Load policies'),
              ),
              if (state.status == PoliciesStatus.success)
                Text(
                  'Policies: ${state.count}',
                  key: PoliciesKeys.result,
                ),
              if (state.status == PoliciesStatus.failure)
                Text(state.error, key: PoliciesKeys.error),
            ],
          );
        },
      ),
    );
  }
}
