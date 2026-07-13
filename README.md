# Cascade Test — Universal Flutter Acceptance-Test Harness

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]
![Dart SDK][dart_sdk_badge]

A reusable, app-agnostic **system-test harness** for Flutter apps, built as a
pub-workspace monorepo. A test pumps the *real* `App` widget with all real
wiring (interceptors, serialization, error mapping, blocs) and fakes only the
outermost I/O boundary (HTTP transport, Firebase SDKs). Configuration is a
synchronous Dart-cascade builder; the UI is driven by `Key`s through BDD robots.

The design goal is that the *same* robots, keys, and test body drive an app
whether its transport is dio, `package:http`, or Firebase — you swap the
transport adapter, nothing else.

It runs entirely in the `flutter_test` widget-test runtime — headless, fast,
and deterministic — and is **not** an on-device or end-to-end tool (it does
not replace `integration_test` or `patrol`); see
[What it is (and is not)](#what-it-is-and-is-not) for the exact scope.

- [Motivation](#motivation)
- [What it is (and is not)](#what-it-is-and-is-not)
- [Status](#status)
- [Packages](#packages)
- [Install](#install)
- [Usage](#usage)
- [Testing by boundary](#testing-by-boundary)
  - [Stubbing (the registry model)](#stubbing-the-registry-model)
  - [HTTP & dio testing](#http--dio-testing)
  - [Firebase testing](#firebase-testing)
  - [Firebase function (callable) testing](#firebase-function-callable-testing)
  - [Live streams & WebSockets](#live-streams--websockets)
  - [Build & observability verbs](#build--observability-verbs)
  - [Running the tests](#running-the-tests)
- [Adoption checklist](#adoption-checklist-make-your-app-injectable)
- [Key convention](#key-convention)
- [Writing robots (chainable DSL)](#writing-robots-chainable-dsl)

## Motivation

Flutter's test tooling is strong at the two ends of the pyramid and thin in the
middle:

- **Isolated unit / bloc tests** (`bloc_test`, `mocktail`) are fast and precise,
  but they *mock the collaborators*. Your real interceptors, JSON
  serialization, retry logic, and error mapping never run — so a whole class of
  wiring bugs (an interceptor that never runs, a serialization step that drops
  a field, a `403` mapped to the wrong app error) stays green and ships. The
  assertions also verify the *mock's* behavior, which drifts from production
  over time.
- **On-device end-to-end tests** (`integration_test`, `patrol`, `maestro`) are
  faithful but expensive: they need an emulator or device, run in minutes, flake
  on timing and network, and make deterministic failure injection (force a
  `403→200` retry, or a `permissionDenied` callable) awkward.

The high-value middle — **pump the real app, fake only the outermost I/O
boundary** — is real but usually hand-rolled per app: a bespoke Dio adapter
here, a `fake_cloud_firestore` seed there, a home-grown robot with no static
safety, rebuilt once per transport and once per project.

Cascade Test standardizes that middle tier. One shared registry backs every
transport, one synchronous cascade programs it, and one key-driven robot
vocabulary drives the UI — so a test runs **as fast and deterministically as a
widget test while exercising as much real code as an integration test**. Because
only the transport is faked, your production error mapping runs for real (a
non-2xx arrives as a real transport response; a failed callable throws the real
`FirebaseFunctionsException`) instead of being reconstructed by a mock. Swap
`useDio` for `useHttpClient` and the same robots, keys, and test body keep
working, so the investment carries across apps and transport migrations.

## What it is (and is not)

Cascade Test runs **entirely in the `flutter_test` widget-test runtime** —
headless, in-process, with no device or emulator. "Acceptance" here means
*app-level behavioral*, verified in that runtime; it does **not** mean
device-verified. It is an orchestration layer built **on top of** the standard
fakes (`fake_cloud_firestore`, `firebase_auth_mocks`, `firebase_storage_mocks`,
Dio's `HttpClientAdapter`, `package:http`'s `MockClient`), not a
rewrite of them.

**It is:**

- An **app-level acceptance / system-test harness** that pumps the *real* `App`
  with real wiring (interceptors, serialization, error mapping, blocs) and fakes
  only the outermost HTTP / Firebase boundary.
- **Fast, headless, and deterministic** — no network, no emulator, no device;
  `pumpUntil`, never `pumpAndSettle`.
- **Transport-agnostic** — the same robots, keys, and test body drive dio,
  `package:http`, and Firebase; you swap only the adapter (AC3).
- A **shared `StubRegistry` + synchronous cascade builder + statically-safe,
  key-driven robot DSL** — `@useResult` chains that cannot silently do nothing.
- A tool for **deterministic failure injection** — force `403→200` retries,
  callable errors (`permissionDenied`, …), latency, and mid-test Firebase
  stream emissions.

**It is not:**

- **Not an on-device / end-to-end tool, and not a replacement for
  `integration_test`, `patrol`, or `maestro`.** It never runs on a real device
  or emulator.
- **Not a test of anything below the faked boundary** — the real network stack,
  Firestore security rules, platform channels, permissions, push notifications,
  deep links, webviews, and native / plugin behavior are all out of scope; cover
  those with a thin on-device E2E layer on top.
- **Not a mocking library** — it fakes the transport boundary rather than
  mocking your repositories or cubits; there is no `when()` / `verify()` on
  collaborators.
- **Not a unit-test framework** — it complements, and does not replace,
  `bloc_test` / `mocktail` unit tests; keep those for branch-level logic.
- **Not a golden / visual-regression tool** — no pixel or golden testing; pair
  with `alchemist` or `golden_toolkit` for that.
- **Not a raw WebSocket / SSE / gRPC-stream harness** — reactive updates are
  modeled as Firebase streams (`.snapshots()`, `authStateChanges()`) only.
- **Not yet on pub.dev** — consumed via a Git dependency (`v0.1.0`,
  `publish_to: none`).

**Where it fits:**

| Tier | Tools | Runs on | Speed | Fidelity |
|---|---|---|---|---|
| Unit / state | `test`, `bloc_test` + `mocktail` | Dart VM, headless | Fastest | Collaborators mocked |
| **App / acceptance** | **Cascade Test** | **Widget-test runtime, headless** | **Fast** | **Real app; only I/O faked** |
| End-to-end | `integration_test`, `patrol`, `maestro` | Device / emulator | Slow | Everything real |

## Status

Merged to `main` (via PR #1) and green on every gate. Verified on
**Flutter 3.44.4 / Dart 3.12.2**:

| Gate | Result |
|---|---|
| `flutter pub get` (workspace root) | resolves the whole workspace |
| `dart analyze` (root, `very_good_analysis`) | **No issues found** |
| Test suite (all 6 packages) | **170 passing, 0 failing** |

Per-package tests: `cascade_core` 102 · `cascade_dio` 13 · `cascade_http` 9 ·
`cascade_firebase` 28 · `demo_dio_firebase` 14 · `demo_http` 4. CI (the VGV
`dart_package` workflow) re-runs analyze + tests + coverage on every push and PR
to `main`, alongside a semantic-PR check and a markdown spell-check.

**Acceptance criteria** (see [docs/test_harness_requirements.md](docs/test_harness_requirements.md)):

| AC | What it proves | State |
|---|---|---|
| AC1 | Full dio + Firebase flow: seeded Firestore, GET, POST `403→200`, callable error, robot login, keys-only driving, `expectCalledWith`. | Met — `demo_dio_firebase` |
| AC2 | An unstubbed call fails fast with the method **and** full path. | Met — `demo_dio_firebase` |
| AC3 | A `package:http` app passes the same-shaped test with only the transport swapped; robot code is byte-identical (machine-checked). | Met — `demo_http` |
| AC4 | Layer A can be added to an app that already has its own harness without breaking it. | Design-level (verifying this literally needs an external app repo) |
| AC5 | No Layer A/B file imports app, Firebase, dio, or http outside its adapter. | Met by construction (dependency graph) + guard tests |
| AC6 | README documents adoption, key convention, and robots. | Met — this file |

**Known gaps** (tracked, not blocking):

- The plan's *100% Layer A/B line-coverage* target is not yet met. Some
  required-surface verbs (`enterPin`/`submitText`) still ship untested.
- Emulator mode (R6.3) and the semantics-label finder (R4.5) are deferred.

## Packages

| Package | Layer | Purpose |
|---|---|---|
| `cascade_core` | A | Registry, cascade builder, `WidgetTesterX`, `Robot`/`TesterRobot`, `HarnessConfig`, observability. App- and transport-agnostic. |
| `cascade_dio` | B | `useDio(dio)` — installs a `FakeHttpClientAdapter` wired to the shared registry. |
| `cascade_http` | B | `useHttpClient()` — installs a registry-backed `MockClient`. |
| `cascade_firebase` | B | `useFirebase()` — callable facade + fake, and Firestore/Auth/Storage seeders. |
| `demo_dio_firebase` | C | Real demo app proving AC1 (full flow) and AC2 (fail-fast). |
| `demo_http` | C | Mirror demo proving AC3 (same flow, only the adapter swapped). |

The **dependency graph** enforces isolation (AC5): `cascade_core` lists no
dio/http/firebase, so a stray transport import in Layer A fails analysis before
any test runs. A `no_forbidden_imports_test` in each Layer A/B package asserts
the same invariant at the source level.

## Install

### Prerequisites

- **Flutter 3.44+** (Dart SDK **≥ 3.12** — every pubspec pins `sdk: ^3.12.0`).
  The repo uses [pub workspaces][pub_workspaces_link], so one resolution covers
  every package.
- Optional: the [Very Good CLI][very_good_cli_link] (`very_good test`) for
  recursive test runs and coverage, matching this project's tooling.

### Work on this repo (run the demos & tests)

```sh
git clone <this-repo-url> cascade_test
cd cascade_test

# One resolution at the workspace root wires up all six packages.
flutter pub get

# Static analysis across the whole workspace.
dart analyze

# Run a package's suite.
cd packages/demo_dio_firebase && flutter test

# …or run everything with coverage via the Very Good CLI.
very_good test --recursive
```

### Adopt the harness in your app

The packages are `publish_to: none` (not on pub.dev), so depend on them from a
Git ref (or vendor them into your own workspace). They are **test-only** — add
them under `dev_dependencies` so no production code depends on the harness:

```yaml
dev_dependencies:
  cascade_core:
    git:
      url: <this-repo-url>
      path: packages/cascade_core
  cascade_dio:        # or cascade_http / cascade_firebase — whichever transports you use
    git:
      url: <this-repo-url>
      path: packages/cascade_dio
```

Then make your `App` injectable (see the [adoption
checklist](#adoption-checklist-make-your-app-injectable)) and write a thin
Layer C `TestApp` (see [Usage](#usage)). Layer A (`cascade_core`) and the
Layer B adapters are independent — add only the transports your app uses.

## Usage

### Anatomy of a harness test

Every test follows the same four beats:

1. **Build** a Layer C `TestApp` (a `TestHarnessBuilder` subclass that installs
   the transport adapters your app uses).
2. **Program** the shared registry with a synchronous cascade — HTTP stubs,
   Firebase seeds, callable stubs.
3. **Pump** the *real* `App`, injecting the faked boundaries.
4. **Drive** the UI with robots (keys only) and **assert** — UI text through the
   chain, then eager registry assertions after the chain drains.

```dart
// test/support/test_app.dart — the one Layer C seam per app.
class TestApp extends TestHarnessBuilder {
  TestApp() {
    withDefaultLatency(const Duration(milliseconds: 5));
    useDio(createAppDio()); // your real Dio, with its real interceptors
    useFirebase();
  }

  Widget build() {
    final harness = buildHarness();
    return App(
      dio: harness.dio,
      firestore: harness.firestore,
      auth: harness.auth,
      callableClient: harness.callableClient,
    );
  }
}
```

### A complete example

```dart
testWidgets('AC1: full dio + Firebase acceptance flow', (tester) async {
  final app = TestApp()
    ..withSignedInUser(uid: 'u1')
    ..withCollection('users', [{'id': 'u1', 'name': 'Ada'}])
    ..withGet('/policies', data: policiesFixture)
    ..withPostSequence('/orders', const [Res(403), Res(200, data: {'id': 'o1'})])
    ..withCallable('createOrder', error: FunctionsError.permissionDenied);

  await tester.pumpWidget(app.build());

  // One fluent chain, drained once by `.run()`; hop robots with `.on()`.
  await LoginRobot(tester)
      .login()
      .on(TesterRobot(tester))
      .tap(PoliciesKeys.loadButton)
      .pumpUntilVisible(PoliciesKeys.result)
      .expectText(PoliciesKeys.result, 'Policies: 2')
      .on(OrdersRobot(tester))
      .submitOrder()
      .expectOrder('o1')
      .run();

  // Eager registry assertions run AFTER the drain so they see the chain's effects.
  app
    ..expectCalledWith('/orders', (body) => body is Map && body['sku'] == 'sku-123',
        method: 'POST')
    ..expectCalled('/orders', method: 'POST', times: 2);
});
```

See [packages/demo_dio_firebase](packages/demo_dio_firebase) for the full,
runnable reference (app wiring in `lib/app/app.dart`, harness in
`test/support/test_app.dart`, flows in `test/acceptance/`).

### Transport installers

Call one installer per transport your app uses, then read the faked boundary
back off the built harness and inject it into your real `App`:

| Installer (cascade verb) | Package | Reads back as |
|---|---|---|
| `useDio(Dio dio)` | `cascade_dio` | `harness.dio` |
| `useHttpClient()` | `cascade_http` | `harness.httpClient` |
| `useFirebase()` | `cascade_firebase` | `harness.firestore`, `harness.auth`, `harness.storage`, `harness.callableClient` |
| `useInstaller(TransportInstaller)` / `addInstallStep(InstallStep)` | `cascade_core` | (custom transport seam) |

Installers are **deferred**: the adapter swap and seeding run inside
`buildHarness()`, never at cascade-call time (R3.1/R3.2), so the builder stays
side-effect-free until you build.

## Testing by boundary

One shared `StubRegistry` backs every transport, so the five surfaces below all
program the same builder and drain through the same chain. Verbs live on
`TestHarnessBuilder` (Layer B packages add theirs by extension) and read as a
`..withX()` cascade; the adapter swap and seeding are **deferred** to
`buildHarness()`, never run at cascade-call time (R3.1/R3.2).

### Stubbing (the registry model)

Every faked boundary — an HTTP request, a callable, a Firestore read — resolves
through one `StubRegistry`. A `withX()` verb registers a **stub** (a matcher plus
an outcome); at run time the adapter builds a `BoundaryRequest`, the registry
resolves it to a `RespondWith` (static data), a `RespondWithHandler` (data
*computed from the request*), or a `FailWith` (a *real* transport error), and the
call is **recorded** for later assertion.

- **`Res(statusCode, {data, latency})`** — the shorthand for one stubbed
  response. A non-2xx status is surfaced as a real transport response so your
  production error mapping runs (D4) — the harness never synthesizes an app
  exception.
- **Sequences** — `withGetSequence(path, List<Res>)` /
  `withPostSequence(path, List<Res>)` return successive `Res`es across repeated
  calls to the same path (R2.6), e.g. `[Res(403), Res(200, data: {...})]` for a
  retry.
- **Computed (handler) outcomes** — `withGetHandler` / `withPostHandler` /
  `withCallableHandler` compute the response from the matched `BoundaryRequest`
  at call time (CR-1), so a stub can model a call whose **server side-effect the
  client reads back** (e.g. a callable that chooses an id, writes
  `offers/{id}` to the fake Firestore, and returns `{offerId}`). The adapter
  awaits the handler exactly once, after the outcome's latency. A handler slots
  into a sequence like any other outcome via `withStub`.
- **`withStub(Stub)`** — the escape hatch: register an arbitrary matcher/outcome
  (including a raw `RespondWithHandler`) when no `withX` verb fits.
- **Latency** — `withDefaultLatency(Duration)` sets the per-stub default (R2.5);
  a verb's own `latency:` overrides it.

**Recording & assertions** (`cascade_core`) — these assert **immediately**, so
call them *after* the chain has drained:

| Verb | Effect |
|---|---|
| `expectCalled(endpoint, {method, times})` | Assert an endpoint was called (optionally N times). |
| `expectNeverCalled(endpoint, {method})` | Assert it was never called. |
| `expectCalledWith(endpoint, bool Function(body), {method})` | Assert some call carried a matching body. |

Turn on `withBoundaryLog()` to print every resolved call
(`[boundary] GET /x -> status 200`) while debugging.

### HTTP & dio testing

Two Layer B adapters share the **exact same** HTTP stub verbs — the only
difference is the installer and the boundary you read back. Program with the
transport-agnostic verbs; swap `useDio` ↔ `useHttpClient` and nothing else
changes (AC3, machine-checked byte-for-byte by `demo_http`).

| Installer | Package | Reads back as |
|---|---|---|
| `useDio(Dio dio)` | `cascade_dio` | `harness.dio` (your real Dio, with its real interceptors) |
| `useHttpClient()` | `cascade_http` | `harness.httpClient` |

**HTTP stub verbs** (`cascade_core`, shared by both adapters):

| Verb | Effect |
|---|---|
| `withGet(path, {data, statusCode = 200, query, latency})` | Stub a `GET`. |
| `withPost(path, {data, statusCode = 200, latency})` | Stub a `POST`. |
| `withPut(path, …)` / `withDelete(path, …)` | Stub a `PUT` / `DELETE`. |
| `withGetSequence(path, List<Res>)` | Successive `GET`s return the sequence in order. |
| `withPostSequence(path, List<Res>)` | `POST` sequence, e.g. `[Res(403), Res(200)]`. |
| `withGetHandler(path, (request) => Res, {query, latency})` | Compute a `GET` response from the request (CR-1). |
| `withPostHandler(path, (request) => Res, {latency})` | Compute a `POST` response from the request (CR-1). |

Handler bodies must be JSON-encodable (the adapters `jsonEncode` them); `Res`
carries no headers and a `Res.latency` returned *inside* a handler is a no-op, so
a header/latency-computing handler drops to `withStub` with a raw
`RespondWithHandler`.

```dart
final app = TestApp()
  ..withGet('/policies', data: policiesFixture)
  ..withPostSequence('/orders', const [Res(403), Res(200, data: {'id': 'o1'})]);
// … pump, drive, then assert the recorded calls:
app.expectCalled('/orders', method: 'POST', times: 2);
```

An **unstubbed** call fails fast with the method **and** full path (AC2) rather
than hanging or returning null, so a missing stub is an immediate, legible
error. Reference: [demo_dio_firebase](packages/demo_dio_firebase) (dio) and
[demo_http](packages/demo_http) (the `package:http` mirror).

### Firebase testing

`useFirebase()` installs in-memory Firestore / Auth / Storage fakes plus the
callable fake, all wired to the shared registry — **no emulator or network
required** (R6.3 emulator mode is deferred). Read the faked boundaries back off
the built harness (`harness.firestore`, `harness.auth`, `harness.storage`,
`harness.callableClient`) and inject them into your real `App`.

**Seed verbs** set *initial* state (for live *updates* mid-test, see
[Live streams & WebSockets](#live-streams--websockets)):

| Verb | Effect |
|---|---|
| `withSignedInUser({uid = 'test-uid', email, claims})` | Seed a signed-in user. |
| `withSignedOutUser()` | Seed a signed-out state. |
| `withCollection(path, List<Map>)` | Seed a Firestore collection (a `String` `'id'` becomes the doc id). |
| `withDocument(path, Map)` | Seed a single document at an explicit path. |
| `withStorageObject(path, contents)` | Seed a fake storage object. |

If a test reads seeded state **before** pumping, build with `buildHarnessAsync()`
so seeds are committed (and any seeding error surfaces) first. Reference:
`test/acceptance/ac1_full_flow_test.dart`.

### Firebase function (callable) testing

Callables flow through the same registry as HTTP, but the app talks to them
through an **app-owned `CallableClient` facade** — the SDK's `FirebaseFunctions`
/ `HttpsCallableResult` have private constructors and cannot be faked directly.
Production wires `FirebaseCallableClient(FirebaseFunctions.instance)`; the
harness injects a registry-backed `FakeCallableClient`, read back as
`harness.callableClient`.

| Verb | Effect |
|---|---|
| `withCallable(name, {data})` | Stub the callable to return `data`. |
| `withCallable(name, {error})` | Throw a **real** `FirebaseFunctionsException` carrying `error.code`. |
| `withCallableHandler(name, (request, firestore) => body)` | Compute the result from the request **and the built fake Firestore** (CR-1) — write a doc, return an id, then read it back. |

`withCallableHandler` late-binds the fake Firestore through the existing
`harness.firestore` accessor, so it requires `useFirebase()` (verb order is
free); without it the accessor's descriptive `StateError` surfaces at the call.
The handler must `await` its own Firestore writes so they commit before the
response is delivered. Reference: the `createOffer` flow in
[test/acceptance/ac5_handler_outcome_test.dart](packages/demo_dio_firebase/test/acceptance/ac5_handler_outcome_test.dart)
and [offers_cubit.dart](packages/demo_dio_firebase/lib/features/offers/offers_cubit.dart).

`error` is a `FunctionsError`: `permissionDenied`, `unauthenticated`,
`notFound`, `invalidArgument`, `unavailable`, `internal`, `cancelled`, or
`unknown`. Because a `FailWith` throws the real SDK exception, your
**callable-error mapping stays above the facade** and runs unchanged (D4) — just
as `ApiException.fromDio` sits above dio:

```dart
final app = TestApp()
  ..withCallable('createOrder', error: FunctionsError.permissionDenied);
// ProfileCubit.createOrder() catches FirebaseFunctionsException and emits
// error.code — the harness never reconstructs the app's mapped error.
```

Reference: the `createOrder` callable in
[profile_cubit.dart](packages/demo_dio_firebase/lib/features/profile/profile_cubit.dart)
and its scenario in `test/acceptance/ac1_full_flow_test.dart`.

### Live streams & WebSockets

The harness has no raw WebSocket transport; **reactive/live updates are modeled
as Firebase streams** — Firestore `.snapshots()` and `authStateChanges()` — which
cover the same "server pushes, the UI re-renders" testing need. The `withX` seed
verbs set the *initial* snapshot; these **post-build emit verbs**
(`FirebaseStreamVerbs` on `Harness`) push *updates* mid-test so live listeners
in the pumped app receive them:

| Verb | Effect |
|---|---|
| `pushDocument(path, data)` | Upsert a document; live snapshots emit. |
| `updateDocument(path, data)` | Update an existing doc (throws not-found like real Firestore). |
| `deleteDocument(path)` | Delete a doc; snapshots emit the removal. |
| `addToCollection(path, data)` | Add an auto-id doc; **returns the new id** for keys-only waits. |
| `emitSignIn({uid, email, claims})` | Sign in mid-test; `authStateChanges()` emits the user. |
| `emitSignOut()` | Sign out mid-test; `authStateChanges()` emits `null`. |

Each verb awaits `Harness.whenReady` before touching the fake, so an emit can
never interleave with pending seed writes. **Writes commit on a later
microtask** — `await` the verb, then `pumpUntil` / `pumpUntilRowGone` the UI
change; never `pumpAndSettle` (real apps have repeating timers). Note that
`authStateChanges()` is a broadcast stream with no replay to late listeners, so
gate the initial render on `auth.currentUser`, not the stream. Full reference:
`test/acceptance/ac4_live_streams_test.dart` and
[messages_cubit.dart](packages/demo_dio_firebase/lib/features/messages/messages_cubit.dart).

### Build & observability verbs

| Verb | Effect |
|---|---|
| `buildHarness()` | Init the binding, install observer/config, run every queued install step, return the populated `Harness`. Plain Dart — never a widget `build`. |
| `buildHarnessAsync()` | `buildHarness()` then `await harness.whenReady` — use when a test reads seeded Firestore/Storage state **before** pumping, so seeds are committed (and any seeding error surfaces) first. |
| `withObserver(BlocObserver)` | Install a `Bloc.observer` at build time — opt-in, never hijacked (AC4). |
| `withConfig(HarnessConfig)` | Register app-specific button/text resolvers read by the tester verbs (R4.4). |

### Running the tests

`flutter pub get` at the workspace root resolves everything at once. Then run
per package with `flutter test`, or across all packages with the Very Good CLI:

```sh
flutter pub get                       # once, at the workspace root
cd packages/cascade_core && flutter test
very_good test --recursive            # all packages
very_good test --coverage             # with coverage (per package)
```

Firebase tests use in-memory fakes, so **no emulator or network is required**.

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

See [packages/demo_dio_firebase/lib/app/app.dart](packages/demo_dio_firebase/lib/app/app.dart)
for a reference wiring. The demo also owns its `CallableClient` facade and
bridges it to the harness in `test/support/test_app.dart`, so production code
never depends on the harness.

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

The base `Robot` verbs are `expectVisible`, `expectNotVisible`, `expectText`,
`tap`, `enterText`, `pumpUntilVisible`, and `tapIfPresent`, plus `step`, `on`,
and `run`. `TesterRobot` adds the remaining low-level `WidgetTesterX` verbs
(`enterPin`, `submitText`, `expectInputHasText`, `expectInputHasFocus`,
`expectButtonEnabled`, `expectButtonDisabled`).

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

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[dart_sdk_badge]: https://img.shields.io/badge/Dart%20SDK-%5E3.12-0175C2.svg
[pub_workspaces_link]: https://dart.dev/tools/pub/workspaces
[very_good_cli_link]: https://pub.dev/packages/very_good_cli
