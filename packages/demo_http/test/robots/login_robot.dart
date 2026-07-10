import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared login flow robot. Byte-identical across the dio and http demos so
/// AC3 holds with zero robot change.
class LoginRobot extends Robot {
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

  /// Enters credentials, submits, and waits for the home page.
  Future<void> login({
    String email = 'ada@example.com',
    String password = 'password123',
  }) async {
    await tester.enterTextByKey(emailField, email);
    await tester.enterTextByKey(passwordField, password);
    await tester.tapButton(loginButton);
    await tester.pumpUntil(find.byKey(homePage));
  }
}
