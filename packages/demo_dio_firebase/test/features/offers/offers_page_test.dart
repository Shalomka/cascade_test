import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:demo_dio_firebase/api/api_client.dart' as demo;
import 'package:demo_dio_firebase/features/offers/offers_keys.dart';
import 'package:demo_dio_firebase/features/offers/offers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bridges the harness's registry-backed [CallableClient] to the demo facade,
/// exactly as `TestApp` does for the real widget.
class _BridgeCallableClient implements demo.CallableClient {
  _BridgeCallableClient(this._delegate);

  final CallableClient _delegate;

  @override
  Future<T> call<T>(String name, {Object? data}) =>
      _delegate.call<T>(name, data: data);
}

void main() {
  group('OffersPage', () {
    Future<void> pumpPage(WidgetTester tester, Harness harness) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OffersPage(
              firestore: harness.firestore,
              callableClient: _BridgeCallableClient(harness.callableClient),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the read-back offer title on success (CR-1)', (
      tester,
    ) async {
      final builder = TestHarnessBuilder()
        ..withDefaultLatency(Duration.zero)
        ..useFirebase()
        ..withCallableHandler('createOffer', (request, firestore) async {
          const id = 'offer-1';
          await firestore.doc('offers/$id').set({'title': 'Hello'});
          return {'offerId': id};
        });
      final harness = await builder.buildHarnessAsync();

      await pumpPage(tester, harness);
      await tester.tap(find.byKey(OffersKeys.createButton));
      await tester.pumpUntil(find.byKey(OffersKeys.result));

      expect(find.text('Offer: Hello'), findsOneWidget);
      expect(find.byKey(OffersKeys.error), findsNothing);
    });

    testWidgets('renders the mapped error code on callable failure (CR-1)', (
      tester,
    ) async {
      final builder = TestHarnessBuilder()
        ..withDefaultLatency(Duration.zero)
        ..useFirebase()
        ..withCallable('createOffer', error: FunctionsError.permissionDenied);
      final harness = await builder.buildHarnessAsync();

      await pumpPage(tester, harness);
      await tester.tap(find.byKey(OffersKeys.createButton));
      await tester.pumpUntil(find.byKey(OffersKeys.error));

      expect(find.text('permission-denied'), findsOneWidget);
      expect(find.byKey(OffersKeys.result), findsNothing);
    });
  });
}
