import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

BoundaryRequest _req(
  String method,
  String endpoint, {
  Object? body,
}) {
  return BoundaryRequest(
    kind: BoundaryKind.http,
    method: method,
    endpoint: endpoint,
    body: body,
  );
}

void main() {
  group('CallRecorder', () {
    late CallRecorder recorder;

    setUp(() => recorder = CallRecorder());

    test('records calls in order and exposes an unmodifiable view', () {
      recorder
        ..record(_req('GET', '/policies'))
        ..record(_req('POST', '/orders'));

      expect(recorder.calls, hasLength(2));
      expect(
        () => recorder.calls.add(
          RecordedCall(
            request: _req('GET', '/x'),
            timestamp: DateTime.now(),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('expectCalled passes when the endpoint was called', () {
      recorder
        ..record(_req('GET', '/policies'))
        ..expectCalled('/policies', method: 'GET');
    });

    test('expectCalled with times asserts the exact count', () {
      recorder
        ..record(_req('POST', '/orders'))
        ..record(_req('POST', '/orders'))
        ..expectCalled('/orders', method: 'POST', times: 2);
    });

    test('expectNeverCalled passes for an untouched endpoint', () {
      recorder
        ..record(_req('GET', '/policies'))
        ..expectNeverCalled('/orders');
    });

    test('expectCalledWith matches on the recorded body', () {
      recorder
        ..record(_req('POST', '/orders', body: {'sku': 'abc'}))
        ..expectCalledWith(
          '/orders',
          (body) => body is Map && body['sku'] == 'abc',
          method: 'POST',
        );
    });

    test('clear removes all recorded calls', () {
      recorder
        ..record(_req('GET', '/policies'))
        ..clear();

      expect(recorder.calls, isEmpty);
    });
  });
}
