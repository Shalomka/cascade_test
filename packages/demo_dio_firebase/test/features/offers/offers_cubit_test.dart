import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:demo_dio_firebase/api/api_client.dart' as demo;
import 'package:demo_dio_firebase/features/offers/offers_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bridges the harness's registry-backed [CallableClient] to the demo's
/// app-owned facade, exactly as `TestApp` does for the real widget.
class _BridgeCallableClient implements demo.CallableClient {
  _BridgeCallableClient(this._delegate);

  final CallableClient _delegate;

  @override
  Future<T> call<T>(String name, {Object? data}) =>
      _delegate.call<T>(name, data: data);
}

void main() {
  group('OffersCubit', () {
    OffersCubit buildCubit(Harness harness) {
      final cubit = OffersCubit(
        firestore: harness.firestore,
        callableClient: _BridgeCallableClient(harness.callableClient),
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test(
      'createOffer invokes the handler, reads the written doc back and emits '
      'success (CR1-S1)',
      () async {
        final builder = TestHarnessBuilder()
          ..withDefaultLatency(Duration.zero)
          ..useFirebase()
          ..withSignedInUser(uid: 'u1')
          ..withCallableHandler('createOffer', (request, firestore) async {
            const id = 'offer-1';
            await firestore.doc('offers/$id').set({'title': 'Hello'});
            return {'offerId': id};
          });
        final harness = await builder.buildHarnessAsync();
        final cubit = buildCubit(harness);

        await cubit.createOffer();

        expect(cubit.state.status, OffersStatus.success);
        expect(cubit.state.offerId, 'offer-1');
        expect(cubit.state.title, 'Hello');
        expect(cubit.state.error, isEmpty);
      },
    );

    test(
      'createOffer maps a FirebaseFunctionsException to failure (CR-1)',
      () async {
        final builder = TestHarnessBuilder()
          ..withDefaultLatency(Duration.zero)
          ..useFirebase()
          ..withSignedInUser(uid: 'u1')
          ..withCallable(
            'createOffer',
            error: FunctionsError.permissionDenied,
          );
        final harness = await builder.buildHarnessAsync();
        final cubit = buildCubit(harness);

        await cubit.createOffer();

        expect(cubit.state.status, OffersStatus.failure);
        expect(cubit.state.error, 'permission-denied');
        expect(cubit.state.title, isEmpty);
      },
    );
  });
}
