---
date: 2026-07-10
topic: chainable-robot-scenario-dsl
---

# Chainable Robot & Scenario DSL

## What We're Building

An **opt-in fluent chaining layer** for the harness's driving/assertion surface, so
a multi-step flow reads as one expression instead of a wall of `await`:

```dart
await profile
    .expectName('Ada')
    .triggerCallable()
    .expectError('permission-denied')
    .run();
```

…and scales to **cross-robot scenarios** by hopping with `.on()`, all sharing one
ordered queue that a single terminal `.run()` drains:

```dart
await login
    .enterCreds('ada', 'pw')
    .submit()
    .on(orders).submitOrder().expectOrder('o1')
    .on(profile).expectName('Ada')
    .run();
```

Single-robot chains, cross-robot scenarios, and low-level tester chains are the
**same lazy step-queue engine**; the only extra primitive is `.on(robot)`.
Chaining is additive and opt-in — imperative, per-line execution stays available
(via `.run()` after a single verb, or the raw `WidgetTesterX` escape hatch) for
breakpoint-level debugging.

## Why This Approach

The engine is a **lazy step-queue**: each verb synchronously appends a *labeled*
closure to a shared `ChainContext` and returns the robot (typed as its concrete
self); nothing executes until `.run()` drains the queue in order. Alternatives
considered and rejected:

- **Eager `extension on Future<WidgetTester>` mirror** — the exact pattern
  R3.3/D5 banned. Every verb defined twice (the "mirror duplication"), and a
  forgotten `await` silently races steps with no lint. Rejected.
- **Bare-await (robot implements `Future`)** — zero-terminal syntax, but
  reintroduces await-magic; an explicit `.run()` marker was preferred instead.
- **Codegen / `noSuchMethod` scenario wrapper** — would let a generic `Scenario`
  expose each robot's domain verbs, but either adds a build_runner toolchain or
  discards static typing. Rejected (YAGNI, type-safety).

The lazy-queue design is the only option that keeps verbs **defined once**
(honoring R3.3's anti-duplication *intent*) while enabling chaining, and both of
its footguns are closed by the analyzer: `@useResult` on every verb catches a
chain built but never `.run()`; `unawaited_futures` catches a `.run()` never
awaited.

## Design Sketch (for the planner)

- `ChainContext { List<ChainStep> steps; bool consumed; }` where
  `ChainStep = (String label, Future<void> Function() thunk)`.
- Base becomes a **CRTP self-type**: `abstract class Robot<Self extends Robot<Self>>`;
  each verb calls `_enqueue('expectName(Ada)', () async {…})` and returns `self`
  so chains stay fully typed across base + domain verbs. Concrete:
  `class ProfileRobot extends Robot<ProfileRobot>`.
- `R on<R extends Robot<R>>(R next)` shares this robot's context with `next` and
  returns `next` (concrete type → its verbs stay in scope).
- `Future<void> run()` drains steps in order; a failing step `i` throws
  `ChainStepError` naming `step i/n · <label>` + the original assertion message
  and stack; `finally` marks the context `consumed`.
- **Lifecycle / reuse:** a verb starts a fresh context when the current one is
  `null` or `consumed`, so a robot instance is reusable across scenarios.
- **Tester chaining:** a concrete `TesterRobot extends Robot<TesterRobot>`
  exposes the R4.3 verbs as chain steps. `WidgetTesterX` itself is unchanged — it
  remains the execution primitive the thunks call.
- **Layering:** all new types live in `cascade_core` (Layer A), additive; no
  transport packages touched (AC5 intact).

## Key Decisions

- **Opt-in, coexists with line-by-line** — chaining is additive; imperative
  debugging stays available. *Amends* (does not delete) R3.3/D5.
- **Fluent `.` chaining, not Dart `..` cascades** — true `..` fires async verbs
  concurrently without ordering; the elegant form is method chaining awaited once.
- **Lazy queue + explicit `.run()` terminal** — obvious "executes now, is async"
  marker; simpler engine (no `Future` impl on the node).
- **Start from any robot; `.on(robot)` hops** — no `Scenario` type; single- and
  multi-robot tests read identically.
- **CRTP self-type + typed `.on<R>()`** — full static typing of chains without
  codegen or `dynamic`.
- **One engine everywhere** — robots, cross-robot scenarios, and `TesterRobot`
  all share `ChainContext`.
- **Debuggability via labeled steps** — `ChainStepError` names which step failed
  and why; directly answers the reason D5 existed.

## Consequence to Confirm (mild tension between two picks)

"Both styles valid" (opt-in) **+** "explicit `.run()`" together imply robot verbs
must **enqueue** (return the robot) rather than execute-and-return `Future<void>`.
So today's `await profile.expectName('Ada');` becomes
`await profile.expectName('Ada').run();`, and the two demo suites get a mechanical
`.run()` migration. The imperative escape hatch is preserved (raw `WidgetTesterX`,
or `.run()` per verb). If the trailing `.run()` on single steps grates, the
fallback is to *also* make the node awaitable (bare-await) — but that reintroduces
the await-magic that was declined.

## Open Questions

- Terminal name: `.run()` vs `.play()` / `.go()` / `.perform()`?
- Migration: auto-rewrite the two demos to `.run()`, or keep a thin
  `Future<void>` compatibility shim on the base for one release?
- Should the chain node **also** be awaitable (drop `.run()` for single steps), or
  is `.run()` strictly mandatory?
- Ship `TesterRobot` (low-level tester chaining) in v1, or robots-only first?
- Failure output: `ChainStepError` (step i/n + cause) only, or also dump the full
  ordered scenario with the failing step marked?
- Confirm `ChainContext` lifecycle rule (fresh on null/consumed; `.run()` marks
  consumed) as the reuse contract.
