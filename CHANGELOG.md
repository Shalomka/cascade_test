# Changelog

All notable changes to the Cascade Test harness are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
All six workspace packages (`cascade_core`, `cascade_dio`, `cascade_http`,
`cascade_firebase`, `demo_dio_firebase`, `demo_http`) are versioned in lockstep
and released under a single `vX.Y.Z` tag.

## [0.2.0] - 2026-07-13

### Added

- **Handler-based stub outcome (CR-1).** A third sealed `StubOutcome` leaf,
  `RespondWithHandler`, computes its `BoundaryResponse` from the matched
  `BoundaryRequest` at call time — so a stub can model a call whose server
  side-effect the client reads back.
  - `cascade_firebase`: `withCallableHandler(name, (request, firestore) => body)`
    late-binds the built fake Firestore through the existing `harness.firestore`
    accessor (e.g. `createOffer` writes `offers/{id}` and returns `{offerId}`,
    which the app reads back).
  - `cascade_core`: `withGetHandler` / `withPostHandler` compute an HTTP response
    from the request. The adapter awaits each handler exactly once, after the
    outcome's latency.
  - Proven end-to-end by the `createOffer` offers feature and
    `ac5_handler_outcome_test` in `demo_dio_firebase`.
- **Live Firebase streams (AC4).** Post-build emit verbs on `Harness`
  (`pushDocument`, `updateDocument`, `deleteDocument`, `addToCollection`,
  `emitSignIn`, `emitSignOut`) push updates mid-test so live `.snapshots()` /
  `authStateChanges()` listeners in the pumped app receive them. `addToCollection`
  returns the new auto-id for keys-only waits.

### Changed

- The dio and `package:http` adapters resolve `StubOutcome` via a `switch`
  statement (was an expression) so a handler outcome is awaited exactly once
  before the transport response is built.
- README: documented the computed/handler outcomes across the "Testing by
  boundary" section and refreshed the Status test counts (170 passing).

## [0.1.0] - 2026-07-10

### Added

- Initial release of the universal Flutter acceptance-test harness: a shared
  `StubRegistry`, a synchronous cascade `TestHarnessBuilder`, `WidgetTesterX`,
  and a statically-safe, key-driven `Robot` / `TesterRobot` chaining DSL.
- Transport adapters wired to the one shared registry: `useDio` (`cascade_dio`),
  `useHttpClient` (`cascade_http`), and `useFirebase` (`cascade_firebase`) with an
  app-owned `CallableClient` facade plus Firestore/Auth/Storage seeders.
- Deterministic failure injection (`403→200` retries, callable `FunctionsError`
  codes, latency), call recording (`expectCalled` / `expectCalledWith`), and
  opt-in boundary-log / `BlocObserver` observability.
- Reference demos proving AC1 (full dio + Firebase flow), AC2 (fail-fast on an
  unstubbed call), and AC3 (`package:http` mirror with byte-identical robots).

[0.2.0]: https://github.com/Shalomka/cascade_test/releases/tag/v0.2.0
[0.1.0]: https://github.com/Shalomka/cascade_test/pull/1
