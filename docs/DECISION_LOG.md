# Wingspan Auto — Decision Log

**Run:** Implement the Universal Flutter Acceptance-Test Harness
(spec vendored at [`docs/test_harness_requirements.md`](test_harness_requirements.md)) inside `cascade_test`.
**Result:** ✅ GOAL MET — local branch `feat/test-harness`, no PR (per your choice).
**Date:** 2026-07-10

## What was built

A 6-package pub-workspace harness under `packages/`:

| Layer | Package | Contents |
|-------|---------|----------|
| A (core, app-agnostic) | `cascade_core` | `StubRegistry` (matching, sequencing, latency, call-recording, fail-fast), side-effect-free cascade `TestApp` builder, `WidgetTesterX` key-driven verbs, `Robot` base, observability (`BlocObserver`/`LoggingObserver`, boundary log) |
| B (transport adapters) | `cascade_dio` | hand-rolled `FakeHttpClientAdapter` at dio's transport boundary |
| B | `cascade_http` | registry-backed `MockClient` |
| B | `cascade_firebase` | faked `CallableClient` facade + `fake_cloud_firestore`/auth/storage seeders |
| C (demos) | `demo_dio_firebase` | proves AC1 (seeded Firestore + GET + POST 403→200 + callable error + login robot + key-driven flow + `expectCalledWith`) and AC2 (unstubbed call fails with method+path) |
| C | `demo_http` | proves AC3 — same test shape with byte-identical robot code, only Layer B/C swapped (enforced by a parity test) |

**Gates (independently verified, not worker-asserted):** `flutter analyze` → *No issues found!*;
full suite → **104 passed, 0 failed**; review → **0 Critical**; diff confined to `packages/` +
declared docs; 4 `no_forbidden_imports_test` guards + transport-free Layer A pubspec enforce AC5.

## Key decisions the run made on its own

1. **Layout:** pub-workspace monorepo under `cascade_test/packages/`, so the dependency graph makes
   AC5's forbidden imports *un-compilable* (AC5 by construction). Root `cascade_test` became a
   workspace umbrella; its 3 placeholder scaffold files were deleted.
2. **Dropped `charlatan`; hand-rolled the dio `FakeHttpClientAdapter`** (~40 lines). Removed a fragile,
   uncached, compat-unverified external dep from the most AC5-sensitive layer. (Superseded brainstorm's
   "use charlatan if compatible".)
3. **Firebase callables via an injected `CallableClient` facade** — `FirebaseFunctions`/`HttpsCallableResult`
   have private constructors and can't be faked directly; the facade's fake throws a real
   `FirebaseFunctionsException`, so the app's own error-mapping stays the system under test (D4/R2.2).
4. **`flutter_test` is a regular dependency of `cascade_core`** (not dev) because its `lib/` imports it;
   this forced `meta ^1.16.0` and dropping the root `test` dev-dep (transitive pins from `flutter_test`).
5. **Deterministic seeding (fix cycle):** added `buildHarnessAsync()` + awaitable `Harness.whenReady`
   so Firestore/Storage seeds commit (and errors surface) before use, while keeping the synchronous
   `buildHarness()` the demos rely on — honoring R3.1/R3.2.

## Auto-resolved assumptions (audit these)

- **A5** Firestore/Auth/Storage are stateful *seeds* outside the call-recording registry; only HTTP + callables
  are recorded/sequenced. Slight divergence from a maximally-literal R2.1, supported by R6.1-vs-R6.2 wording.
- **A6** Emulator mode (R6.3) and semantics finder (R4.5) deferred as stretch — NOT implemented.
- **A11** Callable facade defined app-side in the demo; harness bridges via Layer C `TestApp`.
- **AC2** proven via an unstubbed GET whose `MissingStubError` ("GET /policies") propagates through real error-mapping.

## ⚠️ Deferred / needs your decision

- **AC4 (the reference app's existing suite stays green) was NOT literally satisfied** — it requires
  that *external* app's repo, which is out of scope for this `cascade_test`-only, local-branch run.
  Delivered instead as a **compatibility design + `docs/MIGRATION.md`** (also satisfies AC6's
  migration-note requirement). A real AC4 pass is a separate effort in the reference app's repo.
- **No PR / no remote** — you chose local-branch-only. To open a PR later: create a remote and push
  `feat/test-harness`.
- Review **Suggestions S1–S5** left unaddressed (dead `FinderTextX` export, `useDio` eager-mutation vs
  R3.1, two committed `.flutter-plugins-dependencies`, inconsistent AC5 guard needles, test CWD fragility).

## The 3 things to review most closely before you rely on this

1. **The dio `FakeHttpClientAdapter` (`packages/cascade_dio`)** — it's the load-bearing hand-rolled piece
   replacing `charlatan`. Confirm it faithfully mirrors dio 5.9's `HttpClientAdapter.fetch` contract
   (streaming, headers, `ResponseBody.fromString`) so real interceptors/error-mapping run as intended (D4).
2. **The AC3 parity guarantee (`demo_http` vs `demo_dio_firebase` robots)** — verify the "byte-identical
   robot code" claim is real (the parity test genuinely compares), since that's the core portability promise.
3. **The async-vs-sync seeding split (`buildHarness()` vs `buildHarnessAsync()`, cascade_firebase)** — the
   fix-cycle change. Confirm demos/consumers use the async path where seeded Firestore state must exist
   before the first pump, so the determinism fix actually applies in practice.

_Full stage-by-stage audit trail: `docs/.wingspan-run.md`. Review report: `docs/review/`._

---

## Amendment — Chainable Robot & Scenario DSL (2026-07-10)

**Feature:** an opt-in fluent chaining layer on the robot/tester surface
(`docs/plan/2026-07-10-feat-chainable-robot-scenario-dsl-plan.md`). All new
types live in Layer A `cascade_core`; no transport package or `HarnessConfig`
was touched (AC5 preserved by construction and re-verified).

**Amends R3.3 / D5 (does not delete).** R3.3 banned the
`extension on Future<WidgetTester>` *mirror* because it duplicated every verb and
raced on a forgotten `await`. This design honors R3.3's **intent** — verbs
defined once, on a CRTP base — while enabling chaining, and closes both footguns
statically: a lazy step-queue drained by a mandatory `.run()`, with
`await_only_futures` / `@useResult` / `unawaited_futures` catching the three
misuse shapes (proven by the CH-AC3 `dart analyze` fixture test). Imperative
line-by-line usage and the raw `WidgetTesterX` extension remain valid (opt-in
coexistence, G7).

**New decisions recorded:**

1. **Lazy queue + mandatory `.run()`** (A2/N1) — no bare-await robot, no
   `Future<void>` shim (local-branch harness, no external consumers).
2. **CRTP self-type + typed `.on<R>()`** — one engine for single-robot chains,
   cross-robot scenarios, and the new `TesterRobot`; no `Scenario` type.
   `TesterRobot` shares the base's single verb vocabulary and adds only the
   tester verbs the base lacks (input focus/content, button state, pin, submit)
   — no parallel/duplicate naming (review consolidation).
3. **`ChainStepError` step-context output** (C3) — names `step i/n · <label>`
   and preserves the original stack + matcher diff via
   `Error.throwWithStackTrace`.
4. **Lifecycle** (A4/A5) — a verb starts a fresh context when the current one is
   null or consumed (robot reuse); a consumed `ChainContext` re-run throws
   `StateError`; an empty `.run()` is a no-op; `.on()` asserts a shared tester
   and no pending target chain.
5. **Demos rewritten as full cross-robot chains** (C1); the byte-identical robot
   parity test (AC3) stays green **unmodified**.
6. **`useResult` re-exported from `cascade_core`** so robot authors can annotate
   domain verbs (the never-run static guard) without a direct `meta` dependency.
