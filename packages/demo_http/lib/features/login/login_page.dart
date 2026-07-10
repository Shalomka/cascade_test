import 'package:demo_http/features/login/login_cubit.dart';
import 'package:demo_http/features/login/login_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The key-driven login screen (mirror of the dio demo).
class LoginPage extends StatefulWidget {
  /// Creates a [LoginPage].
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: LoginKeys.form,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              key: LoginKeys.emailField,
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              key: LoginKeys.passwordField,
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            ElevatedButton(
              key: LoginKeys.loginButton,
              onPressed: () => context.read<LoginCubit>().login(
                _email.text,
                _password.text,
              ),
              child: const Text('Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
