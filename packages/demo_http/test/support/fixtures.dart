/// Default fixture payloads shared by the demo's acceptance tests.
///
/// The same payload shapes as the dio demo so AC3 is a same-shaped flow.
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
}
