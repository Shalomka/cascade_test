---
date: 2026-07-12
topic: simulate-firebase-streams
---

# Simulate Firebase Streams (Firestore snapshots + Auth state)

## What We're Building

A first-class way to **simulate live Firebase streams** in the cascade harness —
Firestore `.snapshots()` listeners and `authStateChanges()` — plus a reactive
demo feature and acceptance test that prove it end-to-end.

Today the harness only *seeds initial state* (`withCollection`, `withDocument`,
`withSignedInUser`) and its request/response registry has no notion of a
subscription. The underlying fakes already support real streams
(`fake_cloud_firestore` returns `snapshotStreamController.stream.startWith(...)`
and emits on every write; `firebase_auth_mocks` exposes broadcast
`authStateChanges()`), but three gaps make streaming unproven and un-ergonomic:
(1) no post-build "emit" verb exists, (2) `TestApp.build()` discards the built
`Harness` so a test can't push updates, and (3) no demo/test drives a
`StreamBuilder`. This feature closes all three with thin, awaitable harness verbs
and a real reactive screen in `demo_dio_firebase`.

## Why This Approach

Three shapes were considered for the API (see Key Decisions). We chose **thin,
named verbs on `Harness`** that delegate to the live fakes — symmetric with the
existing `withX` seed verbs, minimal new surface, and honest (they do exactly
what a hand-written `harness.firestore.doc(path).set(...)` would, but named and
discoverable). A `SnapshotDriver`/batching object was rejected as YAGNI, and
"expose the raw fake only" was rejected because the user wants a real harness
API, not a documentation note.

For the proof we chose a **real reactive demo feature + acceptance test** (over a
test-only snippet) so the example is discoverable and mirrors how AC1/AC3 already
document the harness by example. Scope is deliberately **Firestore snapshots +
Auth state** — the two streams that matter for reactive Flutter UIs — and
excludes HTTP/SSE streaming, which needs a fundamentally different registry
outcome type and is a separate, larger effort.

## Key Decisions

- **API shape — thin awaitable verbs on `Harness` (a `cascade_firebase`
  extension).** Rationale: smallest sensible surface, symmetric with the seed
  verbs, and keeps Layer A transport-free (AC5). Proposed verbs:
  - Firestore: `pushDocument(path, data)` (set), `updateDocument(path, data)`
    (merge/update), `deleteDocument(path)`, `addToCollection(path, data)`
    (auto-id add).
  - Auth: `emitSignIn({uid, email, claims})` and `emitSignOut()` — drive
    `authStateChanges()` mid-test.
  - All return `Future<void>` and are awaited, because `fake_cloud_firestore`
    writes are async and the snapshot emission lands on a later microtask (the
    same timing lesson as review I1 / `buildHarnessAsync`). Tests `await` the
    verb, then `pumpUntil` the resulting UI change — never `pumpAndSettle`.

- **Expose the built `Harness` from `TestApp`.** Store it on a field during
  `build()` (`late final Harness harness;`) so tests reach `app.harness` after
  `pumpWidget`. Rationale: consistent with how eager registry assertions
  (`app.expectCalled*`) already run post-build; minimal change; applies to both
  demos' `TestApp`.

- **Scope — Firestore snapshots + Auth state stream.** Storage streaming and
  callable streaming (`HttpsCallable.stream()`) are out of scope; HTTP/SSE is a
  non-goal (see below). Rationale: covers the reactive-UI cases users hit while
  staying focused on the direct ask.

- **Proof — a real reactive demo feature in `demo_dio_firebase` + acceptance
  test.** A new feature (working name **`messages`**: a chat-like live list is
  the canonical `.snapshots()` example) reads
  `firestore.collection(...).snapshots()`, renders a keyed list, and is wired
  into `app.dart` behind the login gate. It also reacts to `authStateChanges()`
  so `emitSignOut()` returns the UI to the gated state. The acceptance test:
  seed messages → assert rows → `await app.harness.addToCollection(...)` →
  `pumpUntil` new-row key → assert list grew → `await app.harness.emitSignOut()`
  → `pumpUntil` login/gate → assert. Driven with the chainable robot DSL,
  keys-only.

- **Reactive read is additive.** The new feature's cubit exposes a `Stream` and
  the UI watches it; existing one-shot features (`policies`, `profile`,
  `orders`) stay unchanged. No regression to AC1/AC2.

## Scope & Non-Goals

**In scope:** Firestore `.snapshots()` simulation (push/add/update/delete),
Auth `authStateChanges()` simulation (sign-in/out), `TestApp.harness` exposure,
one reactive demo feature, its acceptance test, and Layer B unit tests for the
new verbs.

**Non-goals (YAGNI):** no `SnapshotDriver`/batching object; no HTTP or SSE
streaming (needs a new streaming registry outcome + streamed `ResponseBody` /
`MockClient.streaming` — separate effort); no storage-stream or callable-stream
simulation; no conversion of existing one-shot features to streams.

## Constraints & Risks

- **`demo_http` robot parity (AC3).** `robots_parity_test.dart` asserts the
  shared robot files (`login_robot.dart`, `orders_robot.dart`, `robots.dart`)
  are byte-identical across the two demos. The `messages` feature is
  Firestore-based and **cannot exist in `demo_http`**, so its robot must be
  `demo_dio_firebase`-only and **not** added to the byte-locked parity set.
  Confirm the parity test compares only the shared trio; keep the new robot out
  of `robots.dart` if that barrel is parity-checked.

- **Async emit timing (review I1 lesson).** Writes commit on a later microtask;
  the verbs must be awaitable and tests must `pumpUntil` the emission. Asserting
  synchronously right after a push would race.

- **AC5 isolation preserved.** New verbs live in `cascade_firebase` (Layer B)
  and delegate to the fakes; `cascade_core` stays transport-free; the reactive
  UI/keys live in the demo (Layer C).

- **`firebase_auth_mocks` initial-emission nuance.** `authStateChanges()` is a
  broadcast stream and may not replay the current user to a late listener; the
  demo's auth gate should read `currentUser` for initial state and listen to the
  stream for changes. Verify during build.

- **Coverage.** New Layer B verbs need `cascade_firebase` unit tests (emit →
  fake stream emits the expected snapshot / auth event) in addition to the demo
  acceptance test.

## Success Criteria

- **AC-S1** — A harness verb pushes a Firestore doc post-build and a live
  `.snapshots()` listener in the pumped app receives it (demo test: list grows
  mid-test).
- **AC-S2** — `emitSignOut()` drives `authStateChanges()` and the reactive UI
  responds mid-test (returns to the gated/login state).
- **AC-S3** — The new verbs are covered by `cascade_firebase` unit tests, and the
  demo acceptance test is green.
- **AC-S4** — `demo_http` robot parity (AC3) stays green; the streaming robot is
  demo-only and not in the byte-locked set.
- **AC-S5** — `dart analyze` clean; verbs are awaitable; the test uses `pumpUntil`
  (no `pumpAndSettle`).

## Open Questions

- **Demo feature domain:** `messages` (chat-like live list) vs `activity`/
  `watchlist`. Leaning `messages` as the canonical snapshots example — confirm in
  planning.
- **Where auth-reactivity lives:** the existing top-level gate uses a local
  `LoginCubit` (not Firebase auth). To demonstrate `authStateChanges()` we add a
  thin auth listener (in the new feature or a small gate). Decide the minimal
  placement in planning so we don't duplicate the login gate.
- **Verb naming:** imperative post-build names (`pushDocument`/`addToCollection`/
  `emitSignOut`) vs a `with`-parallel. Leaning imperative to signal "runtime
  emit, not initial seed" — confirm.
- **Storage:** confirm we intentionally exclude storage (no meaningful stream) —
  noted as out of scope.
