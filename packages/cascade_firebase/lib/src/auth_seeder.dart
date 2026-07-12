import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Builds a [MockUser] with the given identity and custom [claims] (R6.1).
MockUser buildMockUser({
  required String uid,
  String? email,
  bool isAnonymous = false,
  Map<String, dynamic> claims = const {},
}) {
  return MockUser(
    uid: uid,
    email: email,
    isAnonymous: isAnonymous,
    customClaim: claims,
  );
}

/// Builds a [MockFirebaseAuth] seeded as signed-in ([user]) or signed-out.
///
/// Auth is *initial state*, not a stubbed call, so it never records or fails
/// fast (R6.1).
MockFirebaseAuth buildMockAuth({bool signedIn = false, MockUser? user}) {
  return MockFirebaseAuth(signedIn: signedIn, mockUser: user);
}
