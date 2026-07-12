import 'package:bloc/bloc.dart';

/// The authentication status driving the app's top-level gate.
enum LoginStatus {
  /// No user is signed in; the login form is shown.
  loggedOut,

  /// A user is signed in; the home page is shown.
  loggedIn,
}

/// A minimal real cubit driving login (local validation for the demo).
class LoginCubit extends Cubit<LoginStatus> {
  /// Creates a [LoginCubit] in the logged-out state.
  LoginCubit() : super(LoginStatus.loggedOut);

  /// Signs in when both [email] and [password] are non-empty.
  void login(String email, String password) {
    if (email.isNotEmpty && password.isNotEmpty) {
      emit(LoginStatus.loggedIn);
    }
  }
}
