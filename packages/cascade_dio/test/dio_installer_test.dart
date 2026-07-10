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

        expect(dio.httpClientAdapter, isA<FakeHttpClientAdapter>());

        final harness = builder.buildHarness();
        expect(harness.dio, same(dio));

        final response = await dio.get<Map<String, dynamic>>('/policies');
        expect(response.data, {'ok': true});
      },
    );
  });
}
