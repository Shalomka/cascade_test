import 'package:bloc/bloc.dart';
import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:flutter/foundation.dart';

/// The lifecycle status of a policies load.
enum PoliciesStatus {
  /// Nothing loaded yet.
  initial,

  /// A load is in flight.
  loading,

  /// The load succeeded.
  success,

  /// The load failed (e.g. an unstubbed call, AC2).
  failure,
}

/// Immutable state for the policies feature.
@immutable
class PoliciesState {
  /// Creates a [PoliciesState].
  const PoliciesState({
    this.status = PoliciesStatus.initial,
    this.count = 0,
    this.error = '',
  });

  /// The current lifecycle status.
  final PoliciesStatus status;

  /// The number of policies loaded.
  final int count;

  /// The failure message, when [status] is [PoliciesStatus.failure].
  final String error;
}

/// A real cubit loading policies through the [ApiClient] (the SUT).
class PoliciesCubit extends Cubit<PoliciesState> {
  /// Creates a [PoliciesCubit] over [apiClient].
  PoliciesCubit(this.apiClient) : super(const PoliciesState());

  /// The API client (real interceptors + serialization + error mapping).
  final ApiClient apiClient;

  /// Loads the policies count, mapping failures to [PoliciesStatus.failure].
  Future<void> load() async {
    emit(const PoliciesState(status: PoliciesStatus.loading));
    try {
      final count = await apiClient.fetchPoliciesCount();
      emit(PoliciesState(status: PoliciesStatus.success, count: count));
    } on ApiException catch (error) {
      emit(PoliciesState(status: PoliciesStatus.failure, error: error.message));
    }
  }
}
