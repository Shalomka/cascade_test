# Universal Flutter Acceptance-Test Harness — Requirements

**Status:** Draft for implementation
**Owner:** Robertas Skiauteris
**Prior art:** an existing app-coupled `test/support/test_app.dart` harness,
Betterment's
[end-to-end-ish tests using fake HTTP](https://www.betterment.com/engineering/end-to-end-ish-tests-using-fake-http-in-flutter),
VGV robot pattern.

> Vendored, name-neutral copy of the original requirements. The internal source
> application is referred to throughout as "the reference app".

## 1. Context & Goal

The reference app's front-end has a fluent widget-test harness (`TestApp`) that
boots the whole app, stubs the network at the API-client level, and drives UI by
widget keys through robots. ~100 test files depend on it. It works well but is
app-coupled (imports `App`, `app_ui`, feature keys) and stubs the wrong layer
(the `ApiClient` wrapper instead of the HTTP transport, so interceptors and
error mapping are never exercised and production error-mapping logic is
re-simulated inside stubs).

**Goal:** a reusable harness, extracted as a package, that any of our Flutter
apps (dio-based, `package:http`-based, or Firebase-backed) can adopt by writing
only a thin per-app layer. Tests are full-system: UI → real app wiring → real
interceptors/serialization → stubbed transport → back to UI.

**Definition of "system test" here:** flutter_test `testWidgets` that pumps the
real `App` widget with all real initialization and dependencies, except the
outermost I/O boundary (HTTP transport, Firebase SDKs, platform channels),
which is faked deterministically. No devices, no flutter_driver, fake clock.

## 2. Non-Goals

- NG1. True E2E on devices/emulators against real backends (that is
  `integration_test` territory; see R6.3 for the emulator escape hatch).
- NG2. Golden/screenshot testing.
- NG3. Gherkin/feature-file parsing. Robots provide the BDD readability;
  `bdd_widget_test` may be layered on later but is out of scope.
- NG4. Migrating the reference app's existing ~100 test files. The new harness
  must make incremental migration possible (R1.4) but the migration itself is a
  separate effort.

## 3. Architecture Requirements

- **R1.1 — Three-layer split.**
  - **Layer A (core package, app-agnostic):** stub registry + fluent builder,
    `WidgetTesterX` key-based helpers, `Robot` base class, debug/logging hooks.
    MUST NOT import any app code, `app_ui`, or any specific HTTP/Firebase
    package.
  - **Layer B (adapter packages):** one per transport — `*_dio`, `*_http`,
    `*_firebase`. Each depends on Layer A plus its transport package only.
  - **Layer C (per-app, lives in each app's `test/support/`):** `TestApp`
    builder wiring the real `App` widget, default fixture stubs, robots, and
    harness configuration (button resolvers, text extractors). This is the
    ONLY layer written per app; target ≤ a few hundred lines.
- **R1.2 — Distribution.** Layers A and B live in a standalone repo consumable
  as a git dependency (pub.dev publishing optional, later).
- **R1.3 — Constructor injection prerequisite.** The harness assumes the app
  exposes injection points for every boundary object (dio instance / http
  client / `FirebaseFunctions`, `FirebaseAuth`, `FirebaseFirestore`). Document
  this as an adoption prerequisite; provide a short "make your app injectable"
  checklist in the README. No service locators, no `.instance` statics reached
  directly from app code.
- **R1.4 — Incremental adoption.** An app with an existing hand-rolled harness
  must be able to adopt Layer A helpers and Layer B adapters independently, in
  either order.

## 4. Stub Model Requirements

- **R2.1 — One declarative model for all backends.** A stub is
  `(endpoint, request-matcher) → (response | error, delay)`. "Endpoint" is a
  URL route (HTTP), a callable function name (Firebase Functions), or a
  document/collection path (Firestore seed). Same registry semantics across
  adapters.
- **R2.2 — Mock at the transport boundary.** HTTP stubbing happens at
  `HttpClientAdapter` (dio — use or imitate `charlatan`) or `MockClient`
  (`package:http/testing`). The app's real interceptors, token handling,
  serialization, and error mapping MUST execute in tests. The harness MUST NOT
  reconstruct app-level exceptions (no `ApiClientException.fromDioError` calls
  inside stubs, no magic status codes like the current `250` sentinel).
- **R2.3 — Fail fast.** Any boundary call with no matching stub throws
  immediately with method + full route/function name + request payload in the
  message. No default fallbacks in Layer A/B; per-app default fixture sets are
  a Layer C concern.
- **R2.4 — Matching.** Exact path match by default; explicit opt-in for prefix
  or pattern matching. Optional matchers for query parameters and request
  body. Later registrations override earlier ones (so per-test stubs override
  Layer C defaults).
- **R2.5 — Response ergonomics.** Status code, response body (map/list),
  error/exception injection, and per-stub artificial latency (default ~100ms,
  configurable globally and per stub) so loading states render and can be
  asserted.
- **R2.6 — Sequenced responses.** A stub can return different responses on
  successive calls (e.g. first 403, then 200) to test retry/refresh flows.
- **R2.7 — Call recording.** The registry records every boundary call
  (endpoint, method, payload, timestamp) and exposes assertion helpers:
  `expectCalled(endpoint, times: n)`, `expectNeverCalled(endpoint)`,
  `expectCalledWith(endpoint, bodyMatcher)`.

## 5. Fluent / Cascade API Requirements

- **R3.1 — Cascade-friendly builder.** All configuration methods on the
  builder are synchronous and side-effect-free until `build()`, so Dart `..`
  cascades work:
  ```dart
  final app = TestApp()
    ..withGet('/policies', data: policiesFixture)
    ..withPost('/orders', data: orderFixture, statusCode: 201)
    ..withCallable('createOrder', error: FunctionsError.permissionDenied)
    ..withSignedInUser(uid: 'u1');
  await tester.pumpWidget(app.build());
  ```
- **R3.2 — No side effects in widget `build()`.** Binding initialization,
  observer registration, and storage fakes run in `TestApp.build()` (or
  `setUp`), never inside a widget's `build` method.
- **R3.3 — No future-chaining mirror.** Do not port the
  `extension on Future<WidgetTester>` duplication. Interactions are `await`ed
  line-by-line; readability comes from robots (R5).

## 6. Key-Based Driving Requirements

- **R4.1 — Keys are the only default selector.** All find/tap/enter/expect
  helpers take a `Key`. Finding by widget type is allowed only inside
  helpers/robots as an implementation detail (e.g. descendant `TextField`
  under a keyed form).
- **R4.2 — Key convention.** Keys are declared in per-feature `*_keys.dart`
  files compiled into production code (an existing convention in the reference
  app). Harness README documents the convention.
- **R4.3 — Core helpers (Layer A `WidgetTesterX`).** Port from the reference
  app: `pumpThroughAnimations([duration])`, `expectWidget`, `expectNoWidget`,
  `expectText` (Text + RichText descendants), `tapButton`, `enterTextByKey`,
  `enterPinByKey`, `submitText`, `expectInputHasText`, `expectInputHasFocus`,
  `printOutStringKeys`.
- **R4.4 — Pluggable app-specific widget knowledge.** Harness config accepts:
  - a list of `bool Function(Widget) → enabled?` button resolvers (replaces
    the hardcoded `AppButton`/`AppChoiceButton` checks);
  - custom text extractors `String? Function(Widget)` (replaces the odometer
    special case).
  `expectButtonEnabled/Disabled` and `expectText` consult these before failing.
- **R4.5 — Semantics fallback (nice-to-have).** Optional finder by semantics
  label so tests double as a11y smoke checks.

## 7. BDD Robot Requirements

- **R5.1 — `Robot` base class in Layer A** holding the `WidgetTester` and
  exposing the R4.3 verbs plus `pumpThroughAnimations`.
- **R5.2 — Per-app robots in Layer C** compose verbs into domain language
  (`authRobot.login()`, `sellRobot.submitOrder()`). Test bodies read as
  Given (stubs) / When (robot actions) / Then (robot expectations) with no raw
  `find.byType` or `tester.tap` calls.
- **R5.3 — Conditional steps** supported (`dismissX...IfPresent()` pattern) as
  explicit `...IfPresent` helpers, never silent try/catch.

## 8. Firebase-at-the-Edge Requirements

- **R6.1 — SDK fakes for state-holding services.** Firestore →
  `fake_cloud_firestore`; Auth → `firebase_auth_mocks`; Storage →
  `firebase_storage_mocks`. Builder seeds them declaratively:
  `withCollection('users', [...])`, `withDocument('users/u1', {...})`,
  `withSignedInUser(uid: ..., claims: ...)`, `withSignedOutUser()`.
- **R6.2 — Callable Functions as routes.** `withCallable(name, data: ...)`,
  `withCallable(name, error: code)` in the same registry as HTTP stubs, with
  R2.3–R2.7 semantics (fail-fast, sequencing, call recording). Implemented by
  faking the injected `FirebaseFunctions`/facade.
- **R6.3 — Emulator mode (stretch).** A second adapter implementation that
  points the same seeded state at the Firebase Emulator Suite for
  `integration_test` runs. The Layer C test code MUST NOT change between fake
  mode and emulator mode.
- **R6.4 — No Firebase in Layer A.** All Firebase types stay in the
  `*_firebase` adapter.

## 9. Observability Requirements

- **R7.1 — Boundary call log.** Toggleable per test: every stubbed call
  printed with method, endpoint, status, and latency.
- **R7.2 — State-management observer hook.** Builder accepts an observer
  (e.g. `BlocObserver`) and a ready-made verbose `LoggingObserver`; designed so
  a Riverpod `ProviderObserver` equivalent can be added without Layer A
  changes.
- **R7.3 — Key dump.** Keep `printOutStringKeys()` for debugging.

## 10. Acceptance Criteria

- **AC1.** A demo app in the harness repo (dio + Firebase callable + Firestore)
  has a passing acceptance test that: seeds Firestore, stubs one HTTP GET, one
  HTTP POST returning 403 then 200 (R2.6), one callable error, logs in via a
  robot, drives a flow by keys only, and asserts UI text plus
  `expectCalledWith` on the POST.
- **AC2.** An unstubbed call in the demo fails the test with a message
  containing the method and full path (R2.3).
- **AC3.** A second minimal demo using `package:http` passes the same-shaped
  test with only Layer B/C swapped — zero changes in Layer A or the test's
  robot code.
- **AC4.** The reference app can add the Layer A package alongside its existing
  harness with no breakage (R1.4 smoke: existing suite still green).
- **AC5.** No Layer A/B file imports app code, `app_ui`, Firebase, dio, or
  http outside its designated adapter (enforced by package dependency graph).
- **AC6.** README documents: adoption checklist (R1.3), key convention (R4.2),
  writing robots, and a migration note for apps with existing harnesses.

## 11. Known Design Decisions (do not relitigate)

- D1. Widget-test tier with faked transport, not device E2E (fast,
  deterministic, fake clock).
- D2. Keys over type/text finders (refactor-resistant, localization-proof).
- D3. Robots over Gherkin (readability without a parser dependency).
- D4. Transport-level stubbing over wrapper-level mocks (interceptors and
  error mapping are part of the system under test).
- D5. Sync cascade builder + awaited robot lines; no `Future<T>` chaining
  extensions.
