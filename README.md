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

// One fluent chain, drained once by `.run()`; hop robots with `.on()`.
await LoginRobot(tester)
    .login()
    .on(TesterRobot(tester))
    .tap(PoliciesKeys.loadButton)
    .pumpUntilVisible(PoliciesKeys.result)
    .expectText(PoliciesKeys.result, 'Policies: 2')
    .run();

// Eager registry assertions run AFTER the drain so they see the chain's effects.
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

## Writing robots (chainable DSL)

`Robot<Self>` (Layer A) holds the `WidgetTester` and exposes key-driven verbs.
Each verb **enqueues** a labeled step onto a shared lazy queue and returns the
concrete robot, so a multi-step flow reads as one fluent expression. **Nothing
runs until a terminal `.run()`** drains the queue in order. Per-app robots
extend it and compose domain flows so tests read Given/When/Then with **no raw
`find.byType`/`tester.tap`** (R5.2):

```dart
class LoginRobot extends Robot<LoginRobot> {
  LoginRobot(super.tester);
  static const emailField = Key('email_input');
  static const loginButton = Key('login_button');
  static const homePage = Key('home_page');

  // A verb enqueues via primitives and returns `self`; it never awaits
  // `tester.*` directly. `@useResult` makes a never-run chain a static error.
  @useResult
  LoginRobot login({String email = 'a@b.c', String password = 'pw'}) =>
      enterText(emailField, email).tap(loginButton).pumpUntilVisible(homePage);
}

// A whole scenario is one expression. `.on(robot)` hops to another robot on the
// SAME shared queue; `.run()` drains everything once, in order:
await login
    .login()
    .on(orders).submitOrder().expectOrder('o1')
    .run();
```

### `.on()`, `.run()`, and `TesterRobot`

- **`.on(next)`** transfers the active queue to `next` (which must share the
  same tester) and returns it, so single- and multi-robot tests read
  identically. There is no `Scenario` type.
- **`.run()`** is the only awaitable in a chain. A failing step throws a
  `ChainStepError` naming `step i/n · <label>` and appends the original matcher
  diff. A second `.run()` on the *same* drained queue throws `StateError`; a
  reused robot instance starts a fresh queue for its next chain.
- **`TesterRobot`** shares the base verb vocabulary and adds the remaining
  low-level `WidgetTesterX` verbs (input focus/content, button state, pin entry,
  keyboard submit), so bare-tester interactions join the same engine instead of
  interleaving eager `tester.*` calls with a lazy chain.

### Verb Authoring Contract

1. A verb **enqueues via `step(...)`/primitives and returns `self`** — it never
   `await`s `tester.*` directly, so per-step labels survive.
2. A composite verb calls the robot's own primitives so each sub-action is its
   own labeled step (`login()` → four steps, not one). If a primitive is
   missing (e.g. "pump until a text string appears"), enqueue it with a labeled
   `step(...)` rather than an unlabeled `tester.*` call.
3. Any **find/branch on tree state goes inside the thunk** (run time), never at
   enqueue time — `tapIfPresent` is the canonical example (R5.3).
4. Argument **values** are captured at call time; **tree state** is read at run
   time.
5. **Never use `..` cascades on robots** — a cascade discards each verb's
   returned `self` (and `..run()` discards the future), so the lints below may
   not fire. Use `.` chaining.

### One-level CRTP rule

`Robot<Self extends Robot<Self>>` requires each concrete robot to be a **single
leaf** — `class LoginRobot extends Robot<LoginRobot>`. A two-level hierarchy
loses subclass verbs mid-chain; keep robots one level, or make the intermediate
generic too (`abstract class BaseAppRobot<S extends BaseAppRobot<S>> extends
Robot<S>`).

### Static safety (why chaining has no footguns)

The analyzer closes all three misuse shapes — verified by a `dart analyze`
fixture test (CH-AC3):

| Misuse | Caught by |
| --- | --- |
| chain built, never `.run()` | `@useResult` on every verb → *result discarded* |
| `await robot.verb();` reflex | `await_only_futures` (a robot is not a `Future`) |
| `.run()` never awaited | `unawaited_futures` / `discarded_futures` |

### Escape hatch

Chaining is additive and opt-in: a single-verb chain (`robot.verb().run()`) and
the raw `WidgetTesterX` extension both remain available for breakpoint-level
debugging. Conditional steps are explicit `...IfPresent` verbs (R5.3). Wait for
state with `pumpUntil`, never `pumpAndSettle` (real apps have repeating timers).

## Migration note

Adopt the Layer A helpers and the Layer B adapters **independently, in either
order**, alongside an existing hand-rolled harness. See
[docs/MIGRATION.md](docs/MIGRATION.md) for the incremental adoption path and the
AC4 compatibility argument.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
