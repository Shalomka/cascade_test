import 'package:flutter/widgets.dart';

/// Widget keys for the login feature (R4.2). Identical string values to the
/// dio demo so the shared `LoginRobot` drives both (AC3).
abstract final class LoginKeys {
  /// The login form root.
  static const form = Key('login_form');

  /// The email input field.
  static const emailField = Key('email_input');

  /// The password input field.
  static const passwordField = Key('password_input');

  /// The submit button.
  static const loginButton = Key('login_button');
}
