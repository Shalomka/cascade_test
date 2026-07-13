import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:flutter/foundation.dart';

/// The lifecycle status of an offer creation.
enum OffersStatus {
  /// Nothing created yet.
  initial,

  /// A creation is in flight.
  loading,

  /// The creation succeeded.
  success,

  /// The creation failed.
  failure,
}

/// Immutable state for the offers feature.
@immutable
class OffersState {
  /// Creates an [OffersState].
  const OffersState({
    this.status = OffersStatus.initial,
    this.offerId = '',
    this.title = '',
    this.error = '',
  });

  /// The current lifecycle status.
  final OffersStatus status;

  /// The server-chosen offer id, when successful.
  final String offerId;

  /// The offer title read back from Firestore, when successful.
  final String title;

  /// The mapped callable-error code, when failed.
  final String error;
}

/// A real cubit invoking the `createOffer` callable and reading its
/// server-written document back from Firestore (CR-1).
///
/// The callable computes an id server-side, writes `offers/{offerId}` and
/// returns `{offerId}`; this cubit reads that freshly-written doc back via a
/// one-shot `get()` (parity with `ProfileCubit.load`). The callable-error
/// mapping lives here, *above* the [CallableClient] facade (D4).
class OffersCubit extends Cubit<OffersState> {
  /// Creates an [OffersCubit] with its injected boundaries.
  OffersCubit({required this.firestore, required this.callableClient})
    : super(const OffersState());

  /// The injected Firestore boundary.
  final FirebaseFirestore firestore;

  /// The injected callable facade.
  final CallableClient callableClient;

  /// Invokes `createOffer`, reads the written offer back, and maps errors.
  Future<void> createOffer() async {
    emit(const OffersState(status: OffersStatus.loading));
    try {
      final result = await callableClient.call<Map<String, dynamic>>(
        'createOffer',
      );
      final offerId = (result['offerId'] as String?) ?? '';
      final doc = await firestore.doc('offers/$offerId').get();
      final title = (doc.data()?['title'] as String?) ?? '';
      emit(
        OffersState(
          status: OffersStatus.success,
          offerId: offerId,
          title: title,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      emit(OffersState(status: OffersStatus.failure, error: error.code));
    }
  }
}
