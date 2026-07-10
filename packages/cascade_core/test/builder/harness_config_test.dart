import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/minimal_app.dart';

/// A custom widget the harness cannot recognise without a resolver.
class _CustomToggle extends StatelessWidget {
  const _CustomToggle({required this.enabled, super.key});
  final bool enabled;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  tearDown(resetHarnessConfig);

  group('HarnessConfig globals', () {
    test(
      'configureHarness sets and resetHarnessConfig restores the config',
      () {
        expect(activeHarnessConfig.buttonResolvers, isEmpty);

        configureHarness(
          HarnessConfig(buttonResolvers: [(_) => true]),
        );
        expect(activeHarnessConfig.buttonResolvers, hasLength(1));

        resetHarnessConfig();
        expect(activeHarnessConfig.buttonResolvers, isEmpty);
      },
    );
  });

  group('button resolver precedence (R4.4)', () {
    testWidgets('a resolver takes precedence over the built-in fallback', (
      tester,
    ) async {
      configureHarness(
        HarnessConfig(
          buttonResolvers: [
            (widget) => widget is _CustomToggle ? widget.enabled : null,
          ],
        ),
      );

      await tester.pumpWidget(
        const MinimalApp(
          child: _CustomToggle(enabled: true, key: Key('toggle')),
        ),
      );

      await tester.expectButtonEnabled(const Key('toggle'));
    });

    testWidgets('the first resolver returning non-null wins', (tester) async {
      var secondResolverCalled = false;
      configureHarness(
        HarnessConfig(
          buttonResolvers: [
            (widget) => widget is _CustomToggle ? widget.enabled : null,
            (widget) {
              secondResolverCalled = true;
              return true;
            },
          ],
        ),
      );

      await tester.pumpWidget(
        const MinimalApp(
          child: _CustomToggle(enabled: false, key: Key('toggle')),
        ),
      );

      await tester.expectButtonDisabled(const Key('toggle'));
      expect(secondResolverCalled, isFalse);
    });
  });

  group('text extractor precedence (R4.4)', () {
    testWidgets('an extractor takes precedence over the Text walk', (
      tester,
    ) async {
      configureHarness(
        HarnessConfig(
          textExtractors: [
            (widget) => widget is _CustomToggle ? 'from-extractor' : null,
          ],
        ),
      );

      await tester.pumpWidget(
        const MinimalApp(
          child: _CustomToggle(enabled: true, key: Key('toggle')),
        ),
      );

      await tester.expectText(const Key('toggle'), 'from-extractor');
    });
  });
}
