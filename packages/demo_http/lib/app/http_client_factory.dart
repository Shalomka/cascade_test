import 'package:http/http.dart' as http;

class _AuthClient extends http.BaseClient {
  _AuthClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer token';
    return _inner.send(request);
  }
}

/// Wraps [inner] with the app's real auth-header behavior (the SUT).
///
/// The mirror of the dio demo's request interceptor: the app owns this wiring
/// and the harness only fakes the transport underneath it.
http.Client createAppHttpClient(http.Client inner) => _AuthClient(inner);
