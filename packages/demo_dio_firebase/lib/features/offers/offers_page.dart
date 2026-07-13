import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:demo_dio_firebase/features/offers/offers_cubit.dart';
import 'package:demo_dio_firebase/features/offers/offers_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The offers section: invokes a side-effecting callable and renders the
/// server-written offer title read back from Firestore (CR-1).
class OffersPage extends StatelessWidget {
  /// Creates an [OffersPage] with its injected boundaries.
  const OffersPage({
    required this.firestore,
    required this.callableClient,
    super.key,
  });

  /// The injected Firestore boundary.
  final FirebaseFirestore firestore;

  /// The injected callable facade.
  final CallableClient callableClient;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          OffersCubit(firestore: firestore, callableClient: callableClient),
      child: BlocBuilder<OffersCubit, OffersState>(
        builder: (context, state) {
          return Column(
            children: [
              ElevatedButton(
                key: OffersKeys.createButton,
                onPressed: () => context.read<OffersCubit>().createOffer(),
                child: const Text('Create offer (callable)'),
              ),
              if (state.status == OffersStatus.success)
                Text('Offer: ${state.title}', key: OffersKeys.result),
              if (state.status == OffersStatus.failure)
                Text(state.error, key: OffersKeys.error),
            ],
          );
        },
      ),
    );
  }
}
