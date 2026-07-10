import 'package:cascade_firebase/cascade_firebase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth seeder', () {
    test(
      'builds a signed-in auth exposing uid, email and claims (R6.1)',
      () async {
        final user = buildMockUser(
          uid: 'u1',
          email: 'ada@example.com',
          claims: {'role': 'admin'},
        );
        final auth = buildMockAuth(signedIn: true, user: user);

        expect(auth.currentUser?.uid, 'u1');
        expect(auth.currentUser?.email, 'ada@example.com');

        final token = await auth.currentUser!.getIdTokenResult();
        expect(token.claims?['role'], 'admin');
      },
    );

    test('builds a signed-out auth with no current user (R6.1)', () {
      final auth = buildMockAuth();

      expect(auth.currentUser, isNull);
    });
  });
}
