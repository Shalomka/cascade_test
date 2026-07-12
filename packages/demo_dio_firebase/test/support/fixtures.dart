/// Default fixture payloads shared by the demo's acceptance tests.
abstract final class Fixtures {
  /// A policies list with two entries.
  static const Map<String, dynamic> policies = {
    'items': [
      {'id': 'p1'},
      {'id': 'p2'},
    ],
  };

  /// A created-order response.
  static const Map<String, dynamic> order = {'id': 'o1'};

  /// A seeded user document.
  static const Map<String, dynamic> user = {'id': 'u1', 'name': 'Ada'};

  /// Two seeded live messages with explicit ids so row keys are deterministic.
  static const List<Map<String, dynamic>> messages = [
    {'id': 'm1', 'text': 'first message'},
    {'id': 'm2', 'text': 'second message'},
  ];
}
