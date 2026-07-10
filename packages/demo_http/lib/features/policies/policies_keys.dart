import 'package:flutter/widgets.dart';

/// Widget keys for the policies feature (R4.2). Identical to the dio demo.
abstract final class PoliciesKeys {
  /// The button that triggers the GET.
  static const loadButton = Key('load_policies_button');

  /// The success result text.
  static const result = Key('policies_result');

  /// The failure/error text.
  static const error = Key('policies_error');
}
