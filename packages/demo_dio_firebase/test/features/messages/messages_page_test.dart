import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:demo_dio_firebase/features/messages/messages_keys.dart';
import 'package:demo_dio_firebase/features/messages/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagesPage', () {
    testWidgets('renders the empty state, then the first pushed row', (
      tester,
    ) async {
      final builder = TestHarnessBuilder()
        ..useFirebase()
        ..withSignedInUser(uid: 'u1');
      final harness = builder.buildHarness();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              firestore: harness.firestore,
              auth: harness.auth,
            ),
          ),
        ),
      );

      // Signed in with no seeded collection: the keyed empty state renders.
      await tester.pumpUntil(find.byKey(MessagesKeys.emptyState));

      final id = await harness.addToCollection('messages', {'text': 'first'});

      // The empty→populated transition: first row in, empty state out.
      await tester.pumpUntil(find.byKey(MessagesKeys.row(id)));
      expect(find.byKey(MessagesKeys.emptyState), findsNothing);
      expect(find.byKey(MessagesKeys.list), findsOneWidget);
    });
  });
}
