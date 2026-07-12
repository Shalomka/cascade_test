import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CH-AC3 — the load-bearing static-safety proof.
///
/// Runs `dart analyze` over the fixtures directory (which carries its own
/// `analysis_options.yaml` so the deliberate violations are seen) and asserts a
/// non-zero exit plus the expected lint name for each of the three chain-misuse
/// shapes. This is the machine proof that the analyzer, not discipline, closes
/// the footguns the DSL is designed to avoid.
void main() {
  test(
    'dart analyze flags all three chain-misuse shapes (CH-AC3)',
    () {
      final fixtures = _fixturesDir();

      final result = Process.runSync('dart', [
        'analyze',
        fixtures.path,
      ]);

      final output = '${result.stdout}\n${result.stderr}';

      expect(
        result.exitCode,
        isNot(0),
        reason: 'dart analyze must fail over the misuse fixtures.\n$output',
      );

      // (a) chain built but never `.run()` → discarded @useResult.
      expect(
        output,
        contains('unused_result'),
        reason: 'chain_never_run.dart should trip unused_result.\n$output',
      );
      // (b) `await robot.verb();` reflex → await on a non-Future.
      expect(
        output,
        contains('await_only_futures'),
        reason:
            'await_verb_no_op.dart should trip await_only_futures.\n$output',
      );
      // (c) `.run()` future dropped → unawaited.
      expect(
        output,
        anyOf(contains('unawaited_futures'), contains('discarded_futures')),
        reason:
            'run_not_awaited.dart should trip an unawaited-future lint.'
            '\n$output',
      );
    },
    // Shelling out to the analyzer is slower than a unit test; give it room.
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Resolves the `analyzer_fixtures` directory by walking up from the current
/// directory, so the test is correct regardless of the runner's CWD.
Directory _fixturesDir() {
  const suffix = 'test/chain/analyzer_fixtures';
  for (var dir = Directory.current.absolute; ; dir = dir.parent) {
    // When run from the package root, the fixtures are directly under it.
    final direct = Directory('${dir.path}/$suffix');
    if (direct.existsSync()) return direct;
    // When run from the workspace root, they live under the package.
    final nested = Directory(
      '${dir.path}/packages/cascade_core/$suffix',
    );
    if (nested.existsSync()) return nested;
    if (dir.parent.path == dir.path) {
      throw StateError(
        'Could not locate $suffix from ${Directory.current.absolute.path}',
      );
    }
  }
}
