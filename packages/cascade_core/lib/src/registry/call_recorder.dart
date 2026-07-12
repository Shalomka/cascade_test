import 'package:cascade_core/src/registry/boundary_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

/// A single boundary call captured by the [CallRecorder].
@immutable
final class RecordedCall {
  /// Creates a [RecordedCall].
  const RecordedCall({required this.request, required this.timestamp});

  /// The recorded request.
  final BoundaryRequest request;

  /// When the call was recorded.
  final DateTime timestamp;

  @override
  String toString() => 'RecordedCall(${request.method} ${request.endpoint})';
}

/// Records every boundary call and exposes assertion verbs (R2.7).
final class CallRecorder {
  final List<RecordedCall> _calls = <RecordedCall>[];

  /// An unmodifiable view of all recorded calls, in order.
  List<RecordedCall> get calls => List<RecordedCall>.unmodifiable(_calls);

  /// Records [request] as an attempted boundary call.
  void record(BoundaryRequest request) {
    _calls.add(RecordedCall(request: request, timestamp: DateTime.now()));
  }

  /// Clears all recorded calls.
  void clear() => _calls.clear();

  Iterable<RecordedCall> _matching(String endpoint, String? method) {
    return _calls.where((call) {
      final endpointOk = call.request.endpoint == endpoint;
      final methodOk =
          method == null ||
          call.request.method.toUpperCase() == method.toUpperCase();
      return endpointOk && methodOk;
    });
  }

  String _summary() => _calls
      .map((c) => '${c.request.method} ${c.request.endpoint}')
      .toList()
      .toString();

  /// Asserts [endpoint] was called (optionally by [method], [times] times).
  void expectCalled(String endpoint, {String? method, int? times}) {
    final matching = _matching(endpoint, method).toList();
    if (times != null) {
      expect(
        matching.length,
        times,
        reason:
            'Expected ${method ?? ''} $endpoint called $times time(s), '
            'got ${matching.length}. Recorded: ${_summary()}',
      );
    } else {
      expect(
        matching,
        isNotEmpty,
        reason:
            'Expected a call to ${method ?? ''} $endpoint but none was '
            'recorded. Recorded: ${_summary()}',
      );
    }
  }

  /// Asserts [endpoint] was never called (optionally by [method]).
  void expectNeverCalled(String endpoint, {String? method}) {
    expect(
      _matching(endpoint, method),
      isEmpty,
      reason:
          'Expected no call to ${method ?? ''} $endpoint but one was '
          'recorded. Recorded: ${_summary()}',
    );
  }

  /// Asserts some call to [endpoint] had a body satisfying [bodyMatcher].
  void expectCalledWith(
    String endpoint,
    bool Function(Object? body) bodyMatcher, {
    String? method,
  }) {
    final matching = _matching(endpoint, method).toList();
    final ok = matching.any((call) => bodyMatcher(call.request.body));
    expect(
      ok,
      isTrue,
      reason:
          'No recorded call to ${method ?? ''} $endpoint matched the body '
          'matcher. Bodies: ${matching.map((c) => c.request.body).toList()}',
    );
  }
}
