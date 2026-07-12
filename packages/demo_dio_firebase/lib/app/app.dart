import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_dio_firebase/api/api_client.dart';
import 'package:demo_dio_firebase/features/login/login_cubit.dart';
import 'package:demo_dio_firebase/features/login/login_page.dart';
import 'package:demo_dio_firebase/features/messages/messages_page.dart';
import 'package:demo_dio_firebase/features/orders/orders_page.dart';
import 'package:demo_dio_firebase/features/policies/policies_page.dart';
import 'package:demo_dio_firebase/features/profile/profile_page.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-level widget keys.
abstract final class AppKeys {
  /// The home page shown once logged in.
  static const homePage = Key('home_page');
}

/// The real demo app. Every boundary object is constructor-injected (R1.3) so
/// the harness can fake transport while all app wiring runs for real.
class App extends StatelessWidget {
  /// Creates the [App] with injected boundaries.
  const App({
    required this.dio,
    required this.firestore,
    required this.auth,
    required this.callableClient,
    super.key,
  });

  /// The injected dio (with the app's real interceptors).
  final Dio dio;

  /// The injected Firestore boundary.
  final FirebaseFirestore firestore;

  /// The injected auth boundary.
  final FirebaseAuth auth;

  /// The injected callable facade.
  final CallableClient callableClient;

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(dio);
    return MaterialApp(
      home: BlocProvider(
        create: (_) => LoginCubit(),
        child: BlocBuilder<LoginCubit, LoginStatus>(
          builder: (context, status) {
            if (status == LoginStatus.loggedOut) return const LoginPage();
            return _HomePage(
              apiClient: apiClient,
              firestore: firestore,
              auth: auth,
              callableClient: callableClient,
            );
          },
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.apiClient,
    required this.firestore,
    required this.auth,
    required this.callableClient,
  });

  final ApiClient apiClient;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final CallableClient callableClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.homePage,
      body: SingleChildScrollView(
        child: Column(
          children: [
            PoliciesPage(apiClient: apiClient),
            OrdersPage(apiClient: apiClient),
            ProfilePage(
              firestore: firestore,
              auth: auth,
              callableClient: callableClient,
            ),
            MessagesPage(firestore: firestore, auth: auth),
          ],
        ),
      ),
    );
  }
}
