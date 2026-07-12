import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('TestApp.harness', () {
    test('throws a descriptive StateError when accessed before build()', () {
      final app = TestApp();

      expect(
        () => app.harness,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('before build()'),
          ),
        ),
      );
    });

    testWidgets('returns the built harness after build()', (tester) async {
      final app = TestApp();

      await tester.pumpWidget(app.build());

      expect(app.harness, isNotNull);
    });
  });
}
