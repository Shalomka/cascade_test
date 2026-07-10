import 'package:bloc/bloc.dart';
import 'package:cascade_core/cascade_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

class _IncrementEvent {
  const _IncrementEvent();
}

class _CounterBloc extends Bloc<_IncrementEvent, int> {
  _CounterBloc() : super(0) {
    on<_IncrementEvent>((event, emit) => emit(state + 1));
  }
}

void main() {
  late BlocObserver originalObserver;

  setUp(() => originalObserver = Bloc.observer);
  tearDown(() => Bloc.observer = originalObserver);

  group('LoggingObserver', () {
    test('is a BlocObserver', () {
      expect(const LoggingObserver(), isA<BlocObserver>());
    });

    test('withObserver installs it only at build time (R7.2)', () {
      const observer = LoggingObserver();
      final builder = TestHarnessBuilder()..withObserver(observer);

      expect(Bloc.observer, same(originalObserver));
      builder.buildHarness();
      expect(Bloc.observer, same(observer));
    });

    test('buildHarness without withObserver leaves the observer untouched', () {
      TestHarnessBuilder().buildHarness();

      expect(Bloc.observer, same(originalObserver));
    });

    test('logs lifecycle events without throwing', () async {
      Bloc.observer = const LoggingObserver();
      final cubit = _CounterCubit()..increment();

      expect(cubit.state, 1);

      await cubit.close();
    });

    test('onEvent prints for a Bloc event (R7.2)', () async {
      Bloc.observer = const LoggingObserver();
      final bloc = _CounterBloc();
      addTearDown(bloc.close);

      await expectLater(
        () async {
          bloc.add(const _IncrementEvent());
          await bloc.stream.first;
        },
        prints(contains('EVENT: _CounterBloc')),
      );

      expect(bloc.state, 1);
    });

    test('onError prints the error with the bloc type (R7.2)', () {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);

      expect(
        () => const LoggingObserver().onError(
          cubit,
          StateError('boom'),
          StackTrace.empty,
        ),
        prints(contains('ERROR: _CounterCubit -> Bad state: boom')),
      );
    });
  });
}
