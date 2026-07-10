// The logging observer's purpose is to print bloc lifecycle events (R7.2).
// ignore_for_file: avoid_print

import 'package:bloc/bloc.dart';

/// A verbose [BlocObserver] that prints bloc lifecycle events (R7.2).
///
/// Opt-in only: install it via `TestHarnessBuilder.withObserver` so the
/// harness never hijacks a host app's own observer (key for AC4 compat).
class LoggingObserver extends BlocObserver {
  /// Creates a [LoggingObserver].
  const LoggingObserver();

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    print('----------------------------');
    print('ERROR: ${bloc.runtimeType} -> $error');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    print('----------------------------');
    print('CHANGE: ${bloc.runtimeType} -> $change');
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    print('----------------------------');
    print('EVENT: ${bloc.runtimeType} -> $event');
  }
}
