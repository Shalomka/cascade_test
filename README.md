# Cascade Test — Universal Flutter Acceptance-Test Harness

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A reusable, app-agnostic **system-test harness** for Flutter apps, built as a
pub-workspace monorepo. A test pumps the *real* `App` widget with all real
wiring (interceptors, serialization, error mapping, blocs) and fakes only the
outermost I/O boundary (HTTP transport, Firebase SDKs). Configuration is a
synchronous Dart-cascade builder; the UI is driven by `Key`s through BDD robots.

## Packages

| Package | Layer | Purpose |
|---|---|---|
| `cascade_core` | A | Registry, cascade builder, `WidgetTesterX`, `Robot`, `HarnessConfig`, observability. App- and transport-agnostic. |
| `cascade_dio` | B | Installs a `FakeHttpClientAdapter` wired to the shared registry. |
| `cascade_http` | B | Installs a registry-backed `MockClient`. |
| `cascade_firebase` | B | Callable facade + fake, and Firestore/Auth/Storage seeders. |
| `demo_dio_firebase` | C | Real demo app proving AC1 (full flow) and AC2 (fail-fast). |
| `demo_http` | C | Mirror demo proving AC3 (same flow, only the adapter swapped). |

The **dependency graph** enforces isolation (AC5): `cascade_core` lists no
dio/http/firebase, so a stray transport import in Layer A fails analysis before
any test runs. A `no_forbidden_imports_test` in each Layer A/B package asserts
the same invariant at the source level.

## Quick start

```dart
final app = TestApp() // extends TestHarnessBuilder; installs the adapters
  ..withGet('/policies', data: policiesFixture)
  ..withPostSequence('/orders', const [Res(403), Res(200, data: orderFixture)])
  ..withCallable('createOrder', error: FunctionsError.permissionDenied)
  ..withSignedInUser(uid: 'u1')
  ..withCollection('users', [{'id': 'u1', 'name': 'Ada'}]);

await tester.pumpWidget(app.build());
await LoginRobot(tester).login();
await tester.tapButton(PoliciesKeys.loadButton);
await tester.expectText(PoliciesKeys.result, 'Policies: 2');
app.expectCalledWith('/orders', (body) => body is Map && body['sku'] == 'x');
```

Resolve everything with a single `flutter pub get` at the workspace root, then
run tests per package with the very_good_cli `test` tool (or `flutter test`).

## Adoption checklist (make your app injectable)

To adopt the harness, your app must expose **constructor-injection points** for
every boundary object — the harness swaps the transport, nothing else:

- [ ] `App` takes its `Dio` / `http.Client` by constructor (no `Dio()` created
      inside widgets).
- [ ] `App` takes `FirebaseFirestore`, `FirebaseAuth`, and an app-owned
      `CallableClient` facade by constructor.
- [ ] No `.instance` statics are reached from app code paths under test; no
      service locators or global singletons for boundaries.
- [ ] Production error mapping (e.g. `ApiException.fromDio`) lives **above** the
      transport boundary so the harness never reconstructs app exceptions (D4).
- [ ] Callable-error mapping lives **above** the `CallableClient` facade.

See `packages/demo_dio_firebase/lib/app/app.dart` for a reference wiring.

## Key convention

Declare widget keys in per-feature `*_keys.dart` files compiled into
**production** code (R4.2), and drive tests by `Key` only (D2):

```dart
abstract final class PoliciesKeys {
  static const loadButton = Key('load_policies_button');
  static const result = Key('policies_result');
}
```

Use identical `ValueKey` string values across apps that should share robots.
Never drive tests by widget type or text — always by key.

## Writing robots

`Robot` (Layer A) holds the `WidgetTester` and exposes key-driven verbs.
Per-app robots extend it and compose domain flows so tests read Given/When/Then
with **no raw `find.byType`/`tester.tap`** (R5.2):

```dart
class LoginRobot extends Robot {
  LoginRobot(super.tester);
  static const loginButton = Key('login_button');
  static const homePage = Key('home_page');

  Future<void> login({String email = 'a@b.c', String password = 'pw'}) async {
    await tester.enterTextByKey(Key('email_input'), email);
    await tester.tapButton(loginButton);
    await tester.pumpUntil(find.byKey(homePage)); // never pumpAndSettle
  }
}
```

Conditional steps are explicit `...IfPresent` verbs (R5.3), e.g.
`robot.tapIfPresent(key)`. Wait for state with `pumpUntil`, never
`pumpAndSettle` (real apps have repeating timers).

## Migration note

Adopt the Layer A helpers and the Layer B adapters **independently, in either
order**, alongside an existing hand-rolled harness. See
[docs/MIGRATION.md](docs/MIGRATION.md) for the incremental adoption path and the
AC4 compatibility argument.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
