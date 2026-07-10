import 'package:cascade_core/cascade_core.dart';
import 'package:cascade_dio/cascade_dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DioInstaller', () {
    test(
      'useDio swaps the adapter and exposes the dio via the harness',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        final builder = TestHarnessBuilder()
          ..withDefaultLatency(Duration.zero)
          ..useDio(dio)
          ..withGet('/policies', data: {'ok': true});

        final harness = builder.buildHarness();

        // The adapter swap is deferred to build time (R3.1): only after
        // buildHarness runs does dio carry the fake adapter.
        expect(dio.httpClientAdapter, isA<FakeHttpClientAdapter>());
        expect(harness.dio, same(dio));

        final response = await dio.get<Map<String, dynamic>>('/policies');
        expect(response.data, {'ok': true});
      },
    );

    test('useDio is side-effect-free until buildHarness (R3.1)', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final original = dio.httpClientAdapter;

      TestHarnessBuilder()
        ..withDefaultLatency(Duration.zero)
        ..useDio(dio);

      // No build() yet -> the injected dio is untouched.
      expect(dio.httpClientAdapter, same(original));
      expect(dio.httpClientAdapter, isNot(isA<FakeHttpClientAdapter>()));
    });
  });
}
