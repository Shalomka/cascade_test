# Migration Guide — Adopting the Cascade Test Harness

This guide describes how to adopt the harness incrementally in an app that
already has a hand-rolled widget-test harness (R1.4), and states the
compatibility argument for keeping an existing suite green (AC4).

## Incremental adoption (either order)

Layer A (`cascade_core`) and Layer B adapters are independent. You can adopt
them one at a time, and they coexist with an existing harness because they add
new helpers rather than replacing globals.

### Step 1 — Add Layer A helpers next to your current harness

- Add `cascade_core` as a `dev_dependency`.
- Start using `WidgetTesterX` verbs (`expectText`, `tapButton`, `enterTextByKey`,
  `pumpUntil`, …) and the `Robot` base in new tests. These are pure additions:
  they do not touch `Bloc.observer`, install no globals, and read app-specific
  widgets only through `HarnessConfig` resolvers/extractors you register in
  `setUp` (and clear in `tearDown` via `resetHarnessConfig`).
- Existing tests are unaffected.

### Step 2 — Make your app injectable

Expose constructor-injection points for every boundary object (see the adoption
checklist in the root README). This is the only production change required and
is independently valuable. Until this is done, keep using your existing harness.

### Step 3 — Install a Layer B adapter under the cascade builder

- Add the matching adapter (`cascade_dio`, `cascade_http`, or
  `cascade_firebase`) as a `dev_dependency`.
- Create a thin Layer C `TestApp extends TestHarnessBuilder` that calls
  `useDio` / `useHttpClient` / `useFirebase` and builds your real `App` with the
  installed fakes.
- Migrate tests route-by-route: replace ad-hoc client mocks with
  `withGet` / `withPost` / `withPostSequence` / `withCallable` and seed verbs.
  Because the fake sits at the transport boundary, your real interceptors,
  serialization, and error mapping now run under test (D4).

### Step 4 — Retire the old harness

Once a test file's routes are all expressed through the registry, delete its
dependency on the old harness. Do this file-by-file; the two harnesses can
coexist indefinitely.

## Migrating a robot suite to the chainable DSL

The `Robot` base is chainable: verbs enqueue labeled steps and return the
concrete robot, and a terminal `.run()` drains the queue. Migrating an existing
imperative robot suite is mechanical:

1. **Make the robot a CRTP leaf.** `class LoginRobot extends Robot` becomes
   `class LoginRobot extends Robot<LoginRobot>`. Keep robots one level deep (see
   the one-level rule in the root README).
2. **Rewrite each verb to enqueue and return `self`.** Replace
   `Future<void> verb() async { await tester.x(); await tester.y(); }` with an
   expression that composes the base primitives:
   `@useResult LoginRobot verb() => enterText(...).tap(...).pumpUntilVisible(...);`
   Each primitive is its own labeled step, so failure messages stay granular.
   Annotate domain verbs `@useResult` (re-exported from `cascade_core`) so a
   never-run chain is a static error.
3. **Move any find/branch inside a `step(...)` thunk** so it evaluates at drain
   time, not enqueue time. Prefer explicit `...IfPresent` verbs.
4. **Terminate every chain with `.run()`** and hop robots with `.on(next)`.
   Place eager registry assertions (`app.expectCalled*`) *after* the awaited
   `.run()` so they observe the drained chain's effects.
5. **Drive bare-tester steps through `TesterRobot`** instead of interleaving raw
   `tester.*` calls with a lazy chain.

### The one pitfall — and the lint that catches it

The muscle-memory reflex `await robot.verb();` is a **no-op**: a verb returns the
robot (not a `Future`), so `await` does nothing and the step never runs. This is
exactly the forgotten-`await` footgun the old `extension on Future<WidgetTester>`
mirror suffered — but here the analyzer catches it. Under `very_good_analysis`,
`await_only_futures` flags `await` on a non-`Future`, `@useResult` flags a chain
that is built but never run, and `unawaited_futures` flags a `.run()` whose
future is dropped. A `dart analyze` fixture test (CH-AC3) proves all three fire.
Never use `..` cascades on robots — they discard the returned `self` and can
suppress these lints.

## AC4 compatibility argument (why the existing suite stays green)

Adding Layer A beside an existing harness is non-breaking by construction:

- **No global hijack.** `cascade_core` sets `Bloc.observer` **only** when you
  call `withObserver(...)`. If you never call it, the global observer is left
  exactly as your app or existing harness set it.
- **Minimal, additive dependencies.** `cascade_core` depends only on
  `flutter`/`flutter_test`/`bloc`/`meta` — no transport packages — so it cannot
  collide with your app's HTTP/Firebase stack or pin incompatible versions.
- **No shared mutable state leaked across tests.** `HarnessConfig` is opt-in and
  reset with `resetHarnessConfig()` in `tearDown`; the registry is created per
  `TestHarnessBuilder` instance.
- **Keys, not types.** Robots and `WidgetTesterX` drive by `Key`, so they do not
  depend on your widget class names and won't break when internals change.

A literal "external suite still green" verification requires committing to that
external repository, which is out of scope for this local-branch run (see the
plan's assumption A7). The design above is what makes that verification a
formality rather than a rewrite.
