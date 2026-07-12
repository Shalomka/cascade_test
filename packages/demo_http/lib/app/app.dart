import 'package:demo_http/api/api_client.dart';
import 'package:demo_http/app/http_client_factory.dart';
import 'package:demo_http/features/login/login_cubit.dart';
import 'package:demo_http/features/login/login_page.dart';
import 'package:demo_http/features/orders/orders_page.dart';
import 'package:demo_http/features/policies/policies_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

/// App-level widget keys. Identical string values to the dio demo.
abstract final class AppKeys {
  /// The home page shown once logged in.
  static const homePage = Key('home_page');
}

/// The mirror demo app. The only injected boundary is an [http.Client] (R1.3).
class App extends StatelessWidget {
  /// Creates the [App] with an injected [httpClient].
  const App({required this.httpClient, super.key});

  /// The injected http client (faked transport in tests).
  final http.Client httpClient;

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(createAppHttpClient(httpClient));
    return MaterialApp(
      home: BlocProvider(
        create: (_) => LoginCubit(),
        child: BlocBuilder<LoginCubit, LoginStatus>(
          builder: (context, status) {
            if (status == LoginStatus.loggedOut) return const LoginPage();
            return _HomePage(apiClient: apiClient);
          },
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.apiClient});

  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.homePage,
      body: SingleChildScrollView(
        child: Column(
          children: [
            PoliciesPage(apiClient: apiClient),
            OrdersPage(apiClient: apiClient),
          ],
        ),
      ),
    );
  }
}
