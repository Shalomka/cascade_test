import 'package:cascade_core/cascade_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/minimal_app.dart';

class _Form extends StatefulWidget {
  const _Form();

  static const field = Key('field');
  static const submit = Key('submit');
  static const result = Key('result');

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _controller = TextEditingController();
  String? _submitted;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(key: _Form.field, controller: _controller),
        ElevatedButton(
          key: _Form.submit,
          onPressed: () => setState(() => _submitted = _controller.text),
          child: const Text('Submit'),
        ),
        if (_submitted != null) Text(_submitted!, key: _Form.result),
      ],
    );
  }
}

void main() {
  group('TesterRobot', () {
    testWidgets('each verb enqueues exactly one labeled step', (tester) async {
      await tester.pumpWidget(const MinimalApp(child: _Form()));
      final robot = TesterRobot(tester);

      // Mixes an inherited base verb (enterText) with a TesterRobot-only verb
      // (expectInputHasText); both funnel through `step`.
      final built = robot
          .enterText(_Form.field, 'ada')
          .expectInputHasText(_Form.field, 'ada');

      expect(built.context.length, 2, reason: 'one step per verb');
    });

    testWidgets('run drives the real widget through the tester verbs', (
      tester,
    ) async {
      await tester.pumpWidget(const MinimalApp(child: _Form()));

      await TesterRobot(tester)
          .expectVisible(_Form.field)
          .expectNotVisible(_Form.result)
          .enterText(_Form.field, 'hello')
          .expectInputHasText(_Form.field, 'hello')
          .tap(_Form.submit)
          .pumpUntilVisible(_Form.result)
          .expectText(_Form.result, 'hello')
          .run();
    });

    testWidgets('button-state verbs assert enabled/disabled', (tester) async {
      await tester.pumpWidget(const MinimalApp(child: _Form()));

      await TesterRobot(tester).expectButtonEnabled(_Form.submit).run();
    });
  });
}
