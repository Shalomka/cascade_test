import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';

/// Shared login flow robot. Byte-identical across the dio and http demos so
/// AC3 holds with zero robot change.
class LoginRobot extends Robot<LoginRobot> {
  /// Creates a [LoginRobot] driving [tester].
  LoginRobot(super.tester);

  /// The email input field key.
  static const emailField = Key('email_input');

  /// The password input field key.
  static const passwordField = Key('password_input');

  /// The login button key.
  static const loginButton = Key('login_button');

  /// The home page key (shown after a successful login).
  static const homePage = Key('home_page');

  /// Enters the email and password credentials (one labeled step each).
  @useResult
  LoginRobot enterCreds(String email, String password) =>
      enterText(emailField, email).enterText(passwordField, password);

  /// Submits the form and waits for the home page (never `pumpAndSettle`).
  @useResult
  LoginRobot submit() => tap(loginButton).pumpUntilVisible(homePage);

  /// Enters default credentials and submits, waiting for the home page.
  @useResult
  LoginRobot login({
    String email = 'ada@example.com',
    String password = 'password123',
  }) => enterCreds(email, password).submit();
}
