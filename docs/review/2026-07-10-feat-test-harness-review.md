---
title: Review — Universal Flutter Acceptance-Test Harness
type: review
date: 2026-07-10
branch: feat/test-harness (diff vs main)
reviewer: Wingspan review stage (non-interactive, max effort)
---

# Review — Universal Flutter Acceptance-Test Harness

Scope: `git diff main...HEAD` on `feat/test-harness`, the six new packages under
`packages/` (`cascade_core`, `cascade_dio`, `cascade_http`, `cascade_firebase`,
`demo_dio_firebase`, `demo_http`). Judged against the spec
(`teroxx/front_end/docs/test_harness_requirements.md`, R1.1–R7.3 / AC1–AC6 / D1–D5)
and the plan (`docs/plan/2026-07-10-feat-universal-flutter-acceptance-test-harness-plan.md`).

## Method

- Read every source and test file in the six packages plus both reference docs.
- `flutter pub get` (root) + `flutter analyze packages` → **No issues found** (clean, very_good_analysis).
- Ran all six package test suites via the very_good_cli MCP `test` tool — **all green**:
  cascade_core 55, cascade_dio 9, cascade_http 8, cascade_firebase 12,
  demo_dio_firebase 2 (AC1, AC2), demo_http 4 (AC3 + 3 parity). 90 tests total.
- Measured line coverage on the two most logic-heavy Layer A/B packages via lcov:
  cascade_core ≈ **75.8 %** (229/302), cascade_dio ≈ **75.6 %** (31/41).
- Static sweeps: no `skip`/`solo`/`TODO`, **no `mocktail`/`Mock`/`when(` anywhere**,
  no `pumpAndSettle`, no raw `find.byType`/`tester.tap` inside robots.

## Overall assessment

Strong, spec-faithful implementation. The hardest requirements are genuinely met, not faked:

- **D4 / R2.2 (transport-boundary stubbing) is real.** The dio adapter returns a real
  `ResponseBody`; dio's own `validateStatus` raises a real `DioException`, and the app's
  `ApiException.fromDio` runs as the SUT. The http adapter returns a real `http.Response`;
  the callable fake throws a real `FirebaseFunctionsException` and the app maps its `code`
  *above* the facade. No app exceptions are reconstructed inside stubs; no magic status codes.
  The zero-mocktail sweep confirms the demos exercise real cubits + real wiring.
- **AC1 is a substantive single-flow test** doing all eight required steps (seeded Firestore,
  GET, POST 403→200 via a real retry interceptor, callable error, robot login, key-only
  driving, `expectText` + `expectCalledWith`). **AC2** asserts the fail-fast message reaches
  the UI carrying `GET` + `/policies`. **AC3** passes the mirror flow with byte-identical
  robots enforced by a real machine check (`robots_parity_test`).
- **AC5** holds at the dependency-graph level (cascade_core deps = flutter/flutter_test/bloc/meta,
  no dio/http/firebase) and is double-guarded by source tests; analyze is clean.
- Registry semantics (override R2.4, sequencing R2.6, latency R2.5, recording R2.7,
  fail-fast R2.3) are correct and well-tested. R3.1/R3.2 cascade purity is upheld in the core
  builder; R6.4 (no Firebase in Layer A) holds.

No **Critical** defects: nothing observed breaks a stated AC, no correctness bug reaches a
green-but-wrong test, and no reviewed test is tautological or weakened. The findings below are
robustness and test-gap items (Important) plus polish (Suggestions).

---

## Critical (0)

None.

## Important (3)

### I1 — Fire-and-forget Firebase seeding is not applied at `buildHarness()` return
`packages/cascade_firebase/lib/src/firebase_installer.dart:38-45`

`useFirebase()`'s install step calls `unawaited(seedFirestore(...))` and
`unawaited(seedStorage(...))`. `fake_cloud_firestore`'s `set()` is `async` and `await`s
`maybeThrowSecurityException` **before** it writes
(`fake_cloud_firestore-4.1.1/.../mock_document_reference.dart:211-226`), so the seed write
lands on a later microtask. Consequences:

- `buildHarness()` returns a `Harness` whose Firestore/Storage are **not yet seeded**,
  contradicting the plan's stated contract ("seeds run at `buildHarness()` time"). The
  package's own `firebase_installer_test.dart:28-29` has to insert
  `await Future<void>.delayed(Duration.zero)` to make the seed visible before reading.
- Any seeding error is silently swallowed by `unawaited`.

AC1 passes **deterministically** today only because Dart's microtask FIFO orders the seed
writes (scheduled during `buildHarness`) ahead of the app's first Firestore read (scheduled
later during `pumpWidget` mount), and the robot polls with `pumpUntil`. It is not flaky now,
but it is fragile: a synchronous-ish read after build, or any reordering, would race, and a
bad seed fails silently. Relates to R6.1 / R3.2 intent. *Recommend*: apply seeds synchronously
or make the seed path awaited (e.g. an async build, or drain before returning the harness).

### I2 — Required R4.3 verbs and the R7.1 boundary-log formatter ship with zero tests
`packages/cascade_core/lib/src/tester/widget_tester_x.dart`, `.../observability/boundary_log.dart`

`enterPinByKey`, `expectPinInputHasText`, `submitText` (all named in R4.3) and the explicit-
duration path of `pumpThroughAnimations` have **0 test references**. The R7.1 boundary-call
formatter `formatBoundaryCall`/`logBoundaryCall` is uncovered (0/8 lines) — only the `onResolved`
*wiring* is asserted (`test_harness_builder_test.dart:97`), never the formatted output. These
are stated-requirement surfaces shipped untested (test gap, not a correctness bug).

### I3 — Plan's "100% Layer A/B line coverage" quality gate is not met
cascade_core ≈ 75.8 %, cascade_dio ≈ 75.6 % (measured).

The plan set 100 % line coverage on Layer A/B logic as a Quality Gate and Success Metric.
Beyond I2, notable gaps: `cascade_dio` `fake_http_client_adapter.dart` `_toDioException`
only exercises the `timeout` branch — `connection`/`cancel`/`badResponse`/`callable`/`unknown`
mappings and the response-attachment path are untested; several `TestHarnessBuilder` verbs
(`withPut`, `withDelete`, `withGetSequence`, `withStub`, `expectCalled`, `expectNeverCalled`)
and `LoggingObserver.onError`/`onEvent` are unexercised. Functionality looks correct by
inspection; the gate is simply not satisfied.

## Suggestions (5)

### S1 — `FinderTextX` is exported-but-unused dead code
`packages/cascade_core/lib/src/tester/finder_extensions.dart` (exported in the public barrel).
`verifyText`/`textValues` have **no callers anywhere** and 0/6 coverage; `WidgetTesterX.expectText`
already walks `Text`/`RichText`. Remove it (YAGNI) or route `expectText` through it.

### S2 — `useDio` mutates the injected `Dio` eagerly, diverging from the R3.1 cascade contract
`packages/cascade_dio/lib/src/dio_installer.dart:12-15`. `useDio()` sets
`dio.httpClientAdapter` immediately at cascade-call time instead of inside the queued install
step. Harmless and idempotent, but `useHttpClient`/`useFirebase` both defer their side effects
to build time; for a harness whose selling point is "side-effect-free until build()", make
`useDio` consistent (swap the adapter inside an install step).

### S3 — Committed generated files
`packages/cascade_firebase/.flutter-plugins-dependencies` and
`packages/demo_dio_firebase/.flutter-plugins-dependencies` are generated artifacts committed to
the branch and not covered by `.gitignore`. Add them to `.gitignore` and drop from the tree.

### S4 — `no_forbidden_imports` guards are inconsistent and source-substring based
The four AC5 guard tests use divergent needle sets (`cascade_firebase` uses `package:http/` and
`package:http'`; others use bare `package:http`). They work, but the real AC5 guarantee is the
pubspec graph + analyzer; consider normalizing the needles and noting the tests are a secondary
belt, not the primary enforcement.

### S5 — Cross-package/relative-path fragility in demo tests
`demo_http/test/robots_parity_test.dart` and the AC tests resolve files/paths via relative
`File(...)` and CWD assumptions. Correct under `flutter test` (CWD = package root) and green,
but brittle if invoked from another working directory; consider resolving from a script/package
anchor. (Also minor: `profile_robot` waits on `find.text('Ada')` rather than a key — allowed by
R4.1 inside a robot and justified because the keyed `Text` pre-exists, but slightly against the
keys-only spirit.)

---

## Spec-conformance snapshot (satisfied unless noted)

| Area | Verdict |
|---|---|
| R2.2 / D4 transport-boundary stubbing, real interceptors/mapping run | Met (dio/http/callable all return native shapes; app maps) |
| R2.3 fail-fast method + full route + payload (AC2) | Met (`MissingStubError`; surfaced to UI in AC2) |
| R2.4 override / exact-default / prefix / pattern / query / body | Met (matchers_test) |
| R2.6 sequenced responses | Met (registry + adapters + AC1/AC3) |
| R2.7 call recording + expectCalled/Never/With | Met |
| R3.1/R3.2 sync cascade, side effects in `buildHarness` not widget build | Met in core (see S2 for `useDio`) |
| R4.1 key-only selectors; R4.4 pluggable resolvers/extractors | Met (see S5 minor) |
| R5.1–R5.3 Robot base, domain robots, explicit `...IfPresent` | Met (no raw finders in robots) |
| R6.1 seeds; R6.2 callables through shared registry; R6.4 no Firebase in Layer A | Met — but see I1 (seed timing) |
| R7.1 boundary log; R7.2 opt-in observer (AC4 compat); R7.3 key dump | Implemented; R7.1 formatter untested (I2) |
| AC1 / AC2 / AC3 / AC5 | Demonstrated and green |
| AC4 / AC6 | Docs-only per plan A7; README has all four AC6 sections; `docs/MIGRATION.md` present |
| Coverage gate (plan) | Not met (I3) |

## Auto-resolved assumptions

- **Scope**: reviewed the six `packages/` members only; treated `.claude/**`, `docs/**`, and
  root pipeline files as out of scope (not build-worker harness code).
- **Report location**: written to `docs/review/` per task instructions (the `/review` skill's
  default `docs/code-review/` was overridden as directed).
- **Coverage**: measured cascade_core and cascade_dio (the logic-heavy Layer A/B packages) as a
  representative spot-check of the plan's 100 % gate; did not instrument all six packages.
- **Severity calls**: I1 kept **Important** (not Critical) because AC1 passes deterministically
  today via microtask ordering — flagged as the top fix-cycle candidate. Coverage/test-gap items
  are Important per the review taxonomy (test gaps / gate deviations), not Critical.
