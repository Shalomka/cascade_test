---
title: Chainable Robot & Scenario DSL
type: feat
date: 2026-07-10
---

## ✨ Chainable Robot & Scenario DSL — Extensive Plan

> **Brainstorm:** [`docs/brainstorm/2026-07-10-chainable-robot-scenario-dsl-brainstorm-doc.md`](../brainstorm/2026-07-10-chainable-robot-scenario-dsl-brainstorm-doc.md)
> **Spec (source of truth):** [`docs/test_harness_requirements.md`](../test_harness_requirements.md) — this feature **amends** R3.3 / D5 (see [Decision Log impact](#decision-log-impact)).
> **Prior plan:** [`docs/plan/2026-07-10-feat-universal-flutter-acceptance-test-harness-plan.md`](2026-07-10-feat-universal-flutter-acceptance-test-harness-plan.md) (the harness this layers onto).
> **Produced non-interactively** except for three scoping decisions confirmed by the user (recorded under [Confirmed Decisions](#confirmed-decisions)). Every other fork is resolved toward the simplest spec-compliant option and recorded under [Auto-resolved Assumptions](#auto-resolved-assumptions).

All paths are **relative to the workspace root** `/Users/robertasskiauteris/flutterprojects/cascade_test/`. The build stage may only create/modify the paths enumerated in the [File Manifest](#file-manifest-scope-contract), plus their sibling test files. Anything not listed is out of scope.

---

## Overview

Add an **opt-in fluent chaining layer** to the harness's driving/assertion surface so a
multi-step flow reads as one expression instead of a wall of `await`. The engine is a
**lazy step-queue**: each robot verb synchronously appends a *labeled* closure to a shared
`ChainContext` and returns the robot (typed as its concrete self via CRTP); nothing executes
until a terminal `.run()` drains the queue in order. Cross-robot scenarios are enabled by a
single extra primitive, `.on(robot)`, which shares the queue and hops to the next robot.

```dart
await login
    .enterCreds('ada', 'pw')
    .submit()
    .on(orders).submitOrder().expectOrder('o1')
    .on(profile).expectName('Ada').triggerCallable().expectError('permission-denied')
    .run();
```

Single-robot chains, cross-robot scenarios, and low-level tester chains are the **same
engine**. Chaining is **additive and opt-in**: the imperative escape hatch (`.run()` after a
single verb, or the raw `WidgetTesterX` extension) stays available for breakpoint-level
debugging.

**Layering:** all new types live in `cascade_core` (Layer A). No transport package
(`cascade_dio` / `cascade_http` / `cascade_firebase`) is touched. **AC5** (no transport
imports in Layer A) is preserved by construction and re-verified.

---

## Problem Statement

Today every interaction is `await`ed line-by-line (R3.3 / D5). A five-step cross-screen flow
is fifteen `await` statements; the reading eye reconstructs the scenario from imperative
noise. The reference app's original harness tried to solve this with an
`extension on Future<WidgetTester>` mirror — the exact pattern R3.3 / D5 **banned**, because
every verb had to be defined twice ("mirror duplication") and a forgotten `await` silently
raced steps with no lint to catch it.

We want the *readability* of chaining without either footgun:

1. **No verb duplication** — each verb is defined **once** on the CRTP base (honors R3.3's
   anti-duplication intent).
2. **No silent races** — a lazy queue drained by an explicit `.run()`, with the analyzer
   closing both remaining footguns (see [Analyzer Safety Story](#analyzer-safety-story)).

---

## Goals

- G1. A robot verb enqueues a labeled step and returns its concrete self; chains stay fully
  typed across base + domain verbs with no `dynamic` and no codegen.
- G2. `.on(robot)` hops between robots on one shared queue; single- and multi-robot tests
  read identically. No `Scenario` type.
- G3. `.run()` drains steps in order; a failing step throws a `ChainStepError` naming
  `step i/n · <label>` plus the original assertion message and stack (**Confirmed Decision C3**).
- G4. A `TesterRobot` exposes the R4.3 `WidgetTesterX` verbs as chain steps, so bare-tester
  interactions join the same engine (**Confirmed Decision C2**).
- G5. Both demo suites are rewritten to **showcase full cross-robot chains** (**Confirmed
  Decision C1**); the byte-identical robot parity test (AC3) stays green.
- G6. The analyzer catches all three misuse shapes statically (chain-never-run,
  `await robot.verb()` no-op, `.run()`-never-awaited).
- G7. Imperative line-by-line usage still compiles and runs (opt-in coexistence).

## Non-Goals

- N1. **No bare-await** (robot implementing `Future`) — rejected in brainstorm; reintroduces
  await-magic. `.run()` is mandatory (aligns with the user's saved `.run()` preference).
- N2. **No codegen / `noSuchMethod` scenario wrapper** (YAGNI, type-safety).
- N3. **No `Future<void>` compatibility shim** — this is a local-branch-only harness with no
  release and no external consumers, so a "one release" shim has nothing to bridge. Demos are
  rewritten directly (**Auto-resolved A1**).
- N4. **No parallel/concurrent step execution** — steps run strictly in order.
- N5. **No change to any transport package or `HarnessConfig`.**

---

## Confirmed Decisions

Confirmed by the user during planning:

- **C1 — Demo migration: showcase full chains.** Rewrite each demo flow as one fluent
  expression per scenario, hopping robots with `.on()`. The demos double as the DSL's living
  example.
- **C2 — `TesterRobot` ships in v1.** A `TesterRobot extends Robot<TesterRobot>` exposes the
  R4.3 tester verbs as chain steps. This also lets the demos' policies step (currently raw
  `tester.*`) join the chain, so no eager/lazy interleaving remains in the demos (closes
  flow-gap #6 for the demos).
- **C3 — Failure output: step context + cause.** `ChainStepError` names `step i/n · <label>`
  plus the original assertion message and stack. No full-scenario dump in v1.

## Auto-resolved Assumptions

- **A1.** No compatibility shim (see N3).
- **A2.** Terminal verb is **`.run()`** (saved user preference + brainstorm; not `.play`/`.go`).
- **A3.** **Verb granularity = one labeled step per tester primitive.** Domain verbs
  orchestrate the robot's own enqueuing primitives (they do **not** `await tester.*`
  directly), so `login()` enqueues four labeled steps, not one. This preserves per-step
  labels and avoids the debuggability regression (flow-gap #1). See
  [Verb Authoring Contract](#verb-authoring-contract).
- **A4.** **Double `.run()` on a consumed context throws `StateError`;** empty chain `.run()`
  (fresh context, zero steps) is a no-op that completes and marks consumed (flow-gap #4).
- **A5.** **`.on(next)` asserts `next.tester` is identical to the current robot's tester** and
  that `next` has no pending (non-consumed) context; it transfers the active context to `next`
  and returns `next` (flow-gap #5).
- **A6.** New public types (`Robot`, `ChainContext`, `ChainStepError`, `TesterRobot`) are
  exported from `cascade_core.dart` (flow-gap #12).

---

## Design

### Core types (new: `packages/cascade_core/lib/src/chain/chain_context.dart`)

```dart
/// One labeled, deferred step in a chain. The label feeds ChainStepError.
typedef ChainStep = ({String label, Future<void> Function() thunk});

/// The lazy step-queue shared by a chain. One instance is shared across every
/// robot reached via `.on()` in a single scenario.
class ChainContext {
  final List<ChainStep> _steps = [];
  bool consumed = false;

  void enqueue(String label, Future<void> Function() thunk) =>
      _steps.add((label: label, thunk: thunk));

  int get length => _steps.length;

  /// Drains steps in order. On the first failing step, rethrows a
  /// [ChainStepError] preserving the original stack. Marks [consumed] in a
  /// `finally` so the owning robot starts fresh next time (A4 lifecycle).
  Future<void> run() async {
    if (consumed) {
      throw StateError('This chain has already been run (A4). Build a new chain.');
    }
    try {
      for (var i = 0; i < _steps.length; i++) {
        final step = _steps[i];
        try {
          await step.thunk();
        } catch (e, s) {
          Error.throwWithStackTrace(
            ChainStepError(index: i, total: _steps.length, label: step.label, cause: e),
            s, // preserve the ORIGINAL stack + matcher diff (C3, TestFailure risk)
          );
        }
      }
    } finally {
      consumed = true;
    }
  }
}

/// Thrown by [ChainContext.run] when step i fails. Message names
/// `step (i+1)/n · <label>` and appends the original cause (C3).
class ChainStepError extends Error {
  ChainStepError({required this.index, required this.total, required this.label, required this.cause});
  final int index;
  final int total;
  final String label;
  final Object cause;

  @override
  String toString() =>
      'ChainStepError: step ${index + 1}/$total · $label\n$cause';
}
```

### CRTP base rewrite (`packages/cascade_core/lib/src/robot/robot.dart`)

```dart
/// Base for chainable BDD robots (R5.1). CRTP self-type keeps chains fully
/// typed across base + domain verbs. Concrete robots MUST be a single leaf:
/// `class LoginRobot extends Robot<LoginRobot>` (see CRTP constraint, flow-gap #9).
abstract class Robot<Self extends Robot<Self>> {
  Robot(this.tester);

  final WidgetTester tester;

  ChainContext? _context;

  /// The receiver, statically typed as the concrete robot.
  Self get self => this as Self;

  /// Active context, starting a fresh one when null or consumed (A4).
  ChainContext get context {
    final c = _context;
    if (c == null || c.consumed) return _context = ChainContext();
    return c;
  }

  /// Enqueues a labeled step and returns `self`. Every verb goes through here.
  @useResult
  Self step(String label, Future<void> Function() thunk) {
    context.enqueue(label, thunk);
    return self;
  }

  /// Hops to [next] on the SAME shared queue and returns it (A5).
  @useResult
  R on<R extends Robot<R>>(R next) {
    assert(identical(next.tester, tester),
        '`.on()` requires the next robot to share this tester (flow-gap #5).');
    assert(next._context == null || next._context!.consumed,
        '`.on()` target already has a pending chain (A5).');
    next._context = context;
    return next;
  }

  /// Terminal: drains the queue in order (A2). The only awaitable in a chain.
  Future<void> run() => context.run();

  // --- R4.3 primitive verbs: each enqueues ONE labeled step (A3) ---
  @useResult Self expectVisible(Key key) =>
      step('expectVisible($key)', () => tester.expectWidget(key));
  @useResult Self expectNotVisible(Key key) =>
      step('expectNotVisible($key)', () => tester.expectNoWidget(key));
  @useResult Self expectText(Key key, String text) =>
      step('expectText($key,$text)', () => tester.expectText(key, text));
  @useResult Self tap(Key key) =>
      step('tap($key)', () => tester.tapButton(key));
  @useResult Self enterText(Key key, String text) =>
      step('enterText($key)', () => tester.enterTextByKey(key, text));
  @useResult Self pumpUntilVisible(Key key, {Duration timeout = const Duration(seconds: 10)}) =>
      step('pumpUntilVisible($key)', () => tester.pumpUntil(find.byKey(key), timeout: timeout));

  /// Conditional step — the find/branch runs INSIDE the thunk, at run time,
  /// not at enqueue time (flow-gap #7 / R5.3).
  @useResult Self tapIfPresent(Key key) => step('tapIfPresent($key)', () async {
        if (find.byKey(key).evaluate().isNotEmpty) await tester.tapButton(key);
      });
}
```

> **Note:** `expectVisible`/`expectNotVisible` are additive convenience aliases retained from
> the current base; the underlying `WidgetTesterX` primitives are unchanged.

### `TesterRobot` (new: `packages/cascade_core/lib/src/chain/tester_robot.dart`) — **C2**

`class TesterRobot extends Robot<TesterRobot>` surfacing the R4.3 verbs
(`pumpUntil`, `expectWidget`, `expectText`, `tapButton`, `enterTextByKey`, `enterPinByKey`,
`submitText`, `expectInputHasText`, `expectInputHasFocus`, `expectButtonEnabled/Disabled`) as
enqueuing steps that call the unchanged `WidgetTesterX` primitives in their thunks.
`WidgetTesterX` **itself is not modified** — it remains the execution primitive the thunks
call and the raw imperative escape hatch (G7).

### Verb Authoring Contract

Documented in the README and applied to every migrated domain verb:

1. A verb **enqueues via `step(...)`/primitives and returns `self`**. It never `await`s
   `tester.*` directly (A3 — keeps per-step labels; flow-gap #1).
2. A composite verb calls the robot's own primitives so each sub-action is its own labeled
   step (e.g. `login()` → `enterText(...).enterText(...).tap(...).pumpUntilVisible(...)`).
   Where a primitive is missing (e.g. "pump until a text string appears"), add it to the base
   as a labeled primitive rather than inlining an unlabeled `tester.*` call.
3. Any **find/branch on tree state goes inside the thunk** (run-time), never at enqueue time
   (flow-gap #7).
4. Argument **values** are captured at call time (closure over the parameter); **tree state**
   is read at run time. Documented as the timing contract (flow-gap #8).
5. **Never use `..` cascades on robots** — a cascade discards each verb's returned `self` and
   `..run()` discards the future; `@useResult`/`unawaited_futures` may not fire. Use `.`
   chaining (flow-gap #11).

### CRTP constraint (flow-gap #9)

`Robot<Self extends Robot<Self>>` requires each concrete robot to be a **single leaf**:
`class LoginRobot extends Robot<LoginRobot>`. A two-level app hierarchy
(`SpecificRobot extends BaseAppRobot`) would bind `Self = BaseAppRobot` and lose subclass
verbs mid-chain. Guidance (README + MIGRATION): keep robots one level, or make the
intermediate generic too — `abstract class BaseAppRobot<S extends BaseAppRobot<S>> extends Robot<S>`.

### Composition rule for eager assertions (flow-gap #6)

Registry assertions (`app.expectCalledWith`, `app.expectCalled`) execute **eagerly**. They
must be placed **after** the awaited `.run()`, so they observe the drained chain's effects.
The migrated demos follow: build one chain → `await chain.run();` → then `app.expectCalled*`.

---

## Analyzer Safety Story

Verified against the resolved ruleset `very_good_analysis 10.3.0`
(`analysis_options.10.3.0.yaml`), which enables all three guard lints:

| Misuse | Example | Caught by | Status |
| --- | --- | --- | --- |
| Chain built, never `.run()` | `login.submit();` | `@useResult` on every verb → *result discarded* | ✅ verb-level `@useResult` |
| `await robot.verb();` no-op reflex | `await LoginRobot(t).login();` | `await_only_futures` (robot is **not** a `Future`) | ✅ line 62 |
| `.run()` never awaited | `login.submit().run();` | `unawaited_futures` (async ctx) + `discarded_futures` | ✅ lines 183 / 80 |

This closes the flow-analysis **HIGH** risk (the `await robot.verb()` reflex from muscle
memory): the robot is a plain object, so `await_only_futures` flags it. The safety claim is
verified statically **and** is proven by fixture in **CH-AC3** — it is not left to assertion.

---

## Implementation Phases

Each phase ends green under `dart analyze` (Layer A + demos) and the relevant test run
(`very_good test` / `flutter test`).

### Phase 0 — Analyzer spike (de-risk first)

- [ ] Create a throwaway fixture exercising the three misuse shapes and confirm
      `dart analyze` flags each (formalized as **CH-AC3**). If any shape is *not* flagged,
      stop and escalate before further work (fallback options in [Risks](#risks--mitigations)).
- Files: `packages/cascade_core/test/chain/analyzer_fixtures/` (+ the CH-AC3 test that shells
  out to `dart analyze`).

### Phase 1 — Engine (`ChainContext` + `ChainStepError`)

- [ ] `packages/cascade_core/lib/src/chain/chain_context.dart` — `ChainStep`, `ChainContext`
      (`enqueue`/`run`/`consumed`), `ChainStepError` (C3, stack-preserving).
- [ ] Unit tests: ordered drain; failing step wraps with `step i/n · label` + preserved
      matcher diff; double `.run()` throws `StateError`; empty `.run()` no-ops (A4).
- Files: `chain_context.dart`, `test/chain/chain_context_test.dart`.

### Phase 2 — CRTP `Robot` base rewrite

- [ ] Rewrite `packages/cascade_core/lib/src/robot/robot.dart` to
      `Robot<Self extends Robot<Self>>` with `step`, `on`, `run`, and the R4.3 primitives as
      enqueuing verbs (A3). `tapIfPresent` finds inside the thunk (flow-gap #7).
- [ ] Update `packages/cascade_core/test/robot/robot_test.dart` `_ScreenRobot` to
      `extends Robot<_ScreenRobot>` and assert chains + labels.
- Files: `robot.dart`, `test/robot/robot_test.dart`.

### Phase 3 — `TesterRobot` (C2)

- [ ] `packages/cascade_core/lib/src/chain/tester_robot.dart`.
- [ ] Tests: each verb enqueues one labeled step; `.run()` drives the real widget.
- Files: `tester_robot.dart`, `test/chain/tester_robot_test.dart`.

### Phase 4 — Exports (A6)

- [ ] Add `export 'src/chain/chain_context.dart';` and `export 'src/chain/tester_robot.dart';`
      to `packages/cascade_core/lib/cascade_core.dart` (robot export already present).
- [ ] Confirm `test/no_forbidden_imports_test.dart` still green over the new files (AC5 / CH-AC11).
- Files: `cascade_core.dart`.

### Phase 5 — Demo robot migration (byte-locked, flow-gap #10)

- [ ] Rewrite shared robots to enqueue + return self, **in lockstep** across both demos so
      `robots_parity_test.dart` stays green:
  - `packages/demo_dio_firebase/test/robots/{login_robot,orders_robot,robots}.dart`
  - `packages/demo_http/test/robots/{login_robot,orders_robot,robots}.dart`
- [ ] Rewrite `packages/demo_dio_firebase/test/robots/profile_robot.dart` (dio-only;
      excluded from parity — confirm it stays excluded).
- [ ] `LoginRobot` gains chain-friendly verbs (e.g. `enterCreds`, `submit`) composed from
      primitives; `OrdersRobot.submitOrder/expectOrder`, `ProfileRobot.*` become enqueuing.

### Phase 6 — Demo acceptance rewrite (C1 showcase)

- [ ] `packages/demo_dio_firebase/test/acceptance/ac1_full_flow_test.dart` → one cross-robot
      chain (`login → tester(policies) → orders → profile`), `await …run();`, then
      `app.expectCalledWith/expectCalled` (composition rule). Policies step via `TesterRobot`.
- [ ] `packages/demo_http/test/acceptance/ac3_mirror_flow_test.dart` → same shape (no profile).
- [ ] AC2 (`ac2_unstubbed_call_test.dart`): light touch — only if it drives via a migrated
      verb; otherwise untouched.

### Phase 7 — Acceptance tests for the DSL itself

- [ ] Add the CH-AC test files (see [Acceptance Criteria](#acceptance-criteria)):
      reuse-across-scenarios, `.on()` cross-tester throw, conditional-run-time, escape-hatch,
      `ChainStepError` shape.
- Files under `packages/cascade_core/test/chain/`.

### Phase 8 — Docs & Decision Log

- [ ] `README.md` — chaining section: engine, `.on()`, `.run()`, the Verb Authoring Contract,
      the CRTP one-level rule, never-`..`, escape hatch.
- [ ] `docs/MIGRATION.md` — how to migrate a robot suite to chaining; the `await robot.verb()`
      pitfall and the lint that catches it.
- [ ] `docs/DECISION_LOG.md` — record this feature **amends** R3.3 / D5 (see below).

---

## Decision Log impact

- **Amends R3.3 / D5 (does not delete).** R3.3 banned the `extension on Future<WidgetTester>`
  *mirror* because it duplicated every verb and raced on a forgotten `await`. This design
  honors R3.3's **intent** (verbs defined once, on the CRTP base) while enabling chaining, and
  closes both footguns via the analyzer. Imperative line-by-line usage remains valid (opt-in).
- New decisions recorded: lazy queue + mandatory `.run()` (A2/N1), CRTP self-type + typed
  `.on<R>()`, one engine for robots + scenarios + `TesterRobot` (C2), `ChainStepError`
  step-context output (C3).

---

## File Manifest (Scope Contract)

**New (Layer A `cascade_core`):**

- `packages/cascade_core/lib/src/chain/chain_context.dart`
- `packages/cascade_core/lib/src/chain/tester_robot.dart`
- `packages/cascade_core/test/chain/chain_context_test.dart`
- `packages/cascade_core/test/chain/tester_robot_test.dart`
- `packages/cascade_core/test/chain/chain_error_test.dart`
- `packages/cascade_core/test/chain/robot_lifecycle_test.dart` (reuse, double/empty run, `.on()` cross-tester)
- `packages/cascade_core/test/chain/analyzer_guard_test.dart` (+ `analyzer_fixtures/*.dart`)

**Modified (Layer A):**

- `packages/cascade_core/lib/src/robot/robot.dart` (CRTP rewrite)
- `packages/cascade_core/lib/cascade_core.dart` (exports)
- `packages/cascade_core/test/robot/robot_test.dart` (CRTP + chain assertions)

**Modified (Layer C demos):**

- `packages/demo_dio_firebase/test/robots/{login_robot,orders_robot,profile_robot,robots}.dart`
- `packages/demo_http/test/robots/{login_robot,orders_robot,robots}.dart`
- `packages/demo_dio_firebase/test/acceptance/ac1_full_flow_test.dart`
- `packages/demo_http/test/acceptance/ac3_mirror_flow_test.dart`
- `packages/demo_dio_firebase/test/acceptance/ac2_unstubbed_call_test.dart` (only if it drives via a migrated verb)

**Docs:**

- `README.md`, `docs/MIGRATION.md`, `docs/DECISION_LOG.md`

**Explicitly out of scope:** any `cascade_dio` / `cascade_http` / `cascade_firebase` `lib/`
file; `HarnessConfig`; `WidgetTesterX` verb bodies (only *called*, never modified);
`robots_parity_test.dart` (must stay green **unmodified** — the proof it still holds).

---

## Acceptance Criteria

Existing AC1–AC6 must remain green. New DSL criteria:

- [ ] **CH-AC1 — Single-robot chain.** A chain of ≥3 verbs on one robot passes end-to-end and
      executes in enqueue order (observable ordering asserted).
- [ ] **CH-AC2 — Cross-robot scenario.** AC1's flow recast as one `.on()` chain
      (`login → tester → orders → profile`) passes; AC3's as one chain (no profile).
- [ ] **CH-AC3 — Analyzer guard (mirrors AC2's negative-test style).** `dart analyze` over
      fixtures flags: (a) a chain built but never `.run()`; (b) `await robot.verb();`
      (`await_only_futures`); (c) a `.run()` never awaited (`unawaited_futures`/`discarded_futures`).
      Test shells out to `dart analyze` and asserts non-zero exit + the expected lint names.
- [ ] **CH-AC4 — `ChainStepError` output (C3).** A deliberately failing mid-chain step throws
      `ChainStepError` naming `step i/n · <label>`, and the original matcher **expected/actual
      diff survives** in the message/stack.
- [ ] **CH-AC5 — Robot reuse (A4 lifecycle).** One test runs two chains on the same robot
      instance across two scenarios; the second starts a fresh context (no cross-scenario merge).
- [ ] **CH-AC6 — Double/empty `.run()` (A4).** Second `.run()` on a consumed context throws
      `StateError`; an empty chain `.run()` completes as a no-op.
- [ ] **CH-AC7 — `.on()` cross-tester (A5).** `.on()` with a robot bound to a different tester
      throws (assertion), with a message pointing at the mismatch.
- [ ] **CH-AC8 — Conditional at run time (flow-gap #7).** `tapIfPresent` in a chain evaluates
      the tree at `.run()` time: a widget that appears from an earlier chained step is seen.
- [ ] **CH-AC9 — Parity intact (AC3).** `robots_parity_test.dart` passes **unmodified** after
      the shared robots are rewritten in lockstep.
- [ ] **CH-AC10 — Escape hatch (G7).** `robot.verb().run()` (single verb) and a raw
      `WidgetTesterX` interaction both still compile and pass.
- [ ] **CH-AC11 — Layering (AC5).** `no_forbidden_imports_test.dart` stays green over the new
      chain files (no transport import leaks into Layer A).
- [ ] **CH-AC12 — `TesterRobot` in chain (C2).** A `TesterRobot` drives the demos' policies
      step as chain steps within the cross-robot scenario.

---

## Risks & Mitigations

| # | Risk | Sev | Mitigation |
| --- | --- | --- | --- |
| R1 | `await robot.verb();` silently no-ops and passes green | ~~HIGH~~ → LOW | **Verified**: `await_only_futures` flags it (analyzer story + CH-AC3). Fallback if ever disabled: keep verbs returning a non-awaitable and document. |
| R2 | Debuggability regression from coarse labels | ~~HIGH~~ → LOW | A3: one labeled step per primitive; composite verbs compose primitives. CH-AC4 asserts label granularity. |
| R3 | Lazy-timing correctness bugs (find/branch at enqueue time) | MED | Verb Authoring Contract §3; `tapIfPresent` finds inside thunk; CH-AC8. |
| R4 | `TestFailure` wrapping swallows matcher diff / breaks test zone | MED | `Error.throwWithStackTrace` preserves original stack; append cause verbatim; CH-AC4 asserts the diff survives. |
| R5 | CRTP rigidity (multi-level hierarchies, supertype `.on()` args) | MED | Documented one-level constraint + generic-intermediate escape hatch (flow-gap #9). |
| R6 | Migration underestimated — byte-locked shared robots drift → parity red | MED | Phase 5 edits both copies in lockstep; CH-AC9 gates on unmodified parity test. |
| R7 | Eager `app.expectCalled*` interleaved with lazy chain runs out of order | MED | Composition rule: registry assertions after `await …run()`; demos migrated accordingly. |
| R8 | Undefined double/empty `.run()` and cross-tester `.on()` | LOW | A4/A5 define behavior; CH-AC6/CH-AC7. |

---

## Alternatives Considered (from brainstorm, rejected)

- **Eager `extension on Future<WidgetTester>` mirror** — the R3.3/D5-banned pattern; verb
  duplication + forgotten-`await` races. Rejected.
- **Bare-await (robot implements `Future`)** — zero-terminal syntax but reintroduces
  await-magic; explicit `.run()` preferred (N1).
- **Codegen / `noSuchMethod` scenario wrapper** — build_runner toolchain or lost static
  typing. Rejected (N2).

---

## Open Questions (resolved)

All brainstorm open questions are now resolved: terminal = `.run()` (A2); migration = direct
rewrite, no shim (A1/N3); mandatory `.run()`, no bare-await (N1); `TesterRobot` in v1 (C2);
failure output = step context + cause (C3); lifecycle = fresh-on-null/consumed, double-run
throws, empty-run no-ops (A4).

---

## Testing Strategy

- **Unit** (`ChainContext`): ordering, failure wrapping, lifecycle, double/empty run.
- **Widget** (`Robot`/`TesterRobot`): chains drive a real tree; labels; conditional-at-run-time.
- **Negative/static** (CH-AC3): `dart analyze` fixtures — the load-bearing safety proof.
- **Acceptance** (demos): full cross-robot chains (CH-AC2/CH-AC12) + parity unmodified (CH-AC9).
- Gate each phase on `dart analyze` (Layer A + demos) and `very_good test` for touched packages.
