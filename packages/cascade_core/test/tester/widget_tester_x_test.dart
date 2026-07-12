import 'dart:async';

import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/minimal_app.dart';

class _DelayedReveal extends StatefulWidget {
  const _DelayedReveal();

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? const SizedBox(key: Key('revealed')) : const SizedBox.shrink();
}

void main() {
  tearDown(resetHarnessConfig);

  group('WidgetTesterX', () {
    testWidgets('expectWidget/expectNoWidget assert presence', (tester) async {
      await tester.pumpWidget(
        const MinimalApp(child: SizedBox(key: Key('box'))),
      );

      await tester.expectWidget(const Key('box'));
      await tester.expectNoWidget(const Key('absent'));
    });

    testWidgets('expectText matches a keyed Text widget', (tester) async {
      await tester.pumpWidget(
        const MinimalApp(child: Text('hello', key: Key('greeting'))),
      );

      await tester.expectText(const Key('greeting'), 'hello');
    });

    testWidgets('expectText matches a descendant Text widget', (tester) async {
      await tester.pumpWidget(
        const MinimalApp(
          child: Padding(
            key: Key('wrap'),
            padding: EdgeInsets.zero,
            child: Text('nested'),
          ),
        ),
      );

      await tester.expectText(const Key('wrap'), 'nested');
    });

    testWidgets('expectText matches RichText spans', (tester) async {
      await tester.pumpWidget(
        MinimalApp(
          child: RichText(
            key: const Key('rich'),
            text: const TextSpan(text: 'rich-value'),
          ),
        ),
      );

      await tester.expectText(const Key('rich'), 'rich-value');
    });

    testWidgets('tapButton invokes the button callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MinimalApp(
          child: ElevatedButton(
            key: const Key('cta'),
            onPressed: () => tapped = true,
            child: const Text('Go'),
          ),
        ),
      );

      await tester.tapButton(const Key('cta'));

      expect(tapped, isTrue);
    });

    testWidgets('expectButtonEnabled/Disabled use the Material fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        MinimalApp(
          child: Column(
            children: [
              ElevatedButton(
                key: const Key('enabled'),
                onPressed: () {},
                child: const Text('On'),
              ),
              const ElevatedButton(
                key: Key('disabled'),
                onPressed: null,
                child: Text('Off'),
              ),
            ],
          ),
        ),
      );

      await tester.expectButtonEnabled(const Key('enabled'));
      await tester.expectButtonDisabled(const Key('disabled'));
    });

    testWidgets('enterTextByKey fills the field and reports value + focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        MinimalApp(
          child: TextField(
            key: const Key('email'),
            controller: TextEditingController(),
            focusNode: FocusNode(),
          ),
        ),
      );

      await tester.enterTextByKey(const Key('email'), 'ada@x.io');

      await tester.expectInputHasText(const Key('email'), 'ada@x.io');
      await tester.expectInputHasFocus(const Key('email'));
    });

    testWidgets(
      'enterPinByKey fills the EditableText and expectPinInputHasText '
      'reads it back',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MinimalApp(
            child: TextField(key: const Key('pin'), controller: controller),
          ),
        );

        await tester.enterPinByKey(const Key('pin'), '1234');

        await tester.expectPinInputHasText(const Key('pin'), '1234');
        expect(controller.text, '1234');
      },
    );

    testWidgets('submitText fires the focused field submit action', (
      tester,
    ) async {
      String? submittedValue;
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MinimalApp(
          child: TextField(
            key: const Key('search'),
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (value) => submittedValue = value,
          ),
        ),
      );

      await tester.enterTextByKey(const Key('search'), 'query');
      await tester.submitText();

      expect(submittedValue, 'query');
    });

    testWidgets(
      'pumpThroughAnimations with an explicit duration advances the clock',
      (tester) async {
        await tester.pumpWidget(const MinimalApp(child: _DelayedReveal()));

        // _DelayedReveal flips at 250ms; two 200ms pumps (400ms) reveal it.
        final result = await tester.pumpThroughAnimations(
          const Duration(milliseconds: 200),
        );

        expect(result, same(tester));
        expect(find.byKey(const Key('revealed')), findsOneWidget);
      },
    );

    testWidgets('pumpUntil waits for a delayed widget deterministically', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _DelayedReveal()));

      await tester.pumpUntil(find.byKey(const Key('revealed')));

      expect(find.byKey(const Key('revealed')), findsOneWidget);
    });

    testWidgets('pumpUntil fails when the widget never appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MinimalApp(child: SizedBox(key: Key('box'))),
      );

      Object? caught;
      try {
        await tester.pumpUntil(
          find.byKey(const Key('never')),
          timeout: const Duration(milliseconds: 300),
        );
      } on TestFailure catch (error) {
        caught = error;
      }

      expect(caught, isA<TestFailure>());
    });

    testWidgets('printOutStringKeys runs without error', (tester) async {
      await tester.pumpWidget(
        const MinimalApp(child: SizedBox(key: Key('box'))),
      );

      expect(tester.printOutStringKeys, returnsNormally);
    });
  });
}
