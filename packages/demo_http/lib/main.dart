import 'package:demo_http/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// The production entrypoint wiring the real http transport.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(httpClient: http.Client()));
}
