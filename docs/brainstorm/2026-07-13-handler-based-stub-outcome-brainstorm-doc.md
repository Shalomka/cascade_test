---
date: 2026-07-13
topic: handler-based-stub-outcome
---

# CR-1 — Handler-Based Stub Outcome (dynamic, side-effecting responses)

## What We're Building

A third `StubOutcome` leaf — **`RespondWithHandler`** — that computes its
response from the matched `BoundaryRequest` at call time instead of returning a
pre-baked body. Every outcome today is static: `RespondWith(staticData)` /
`FailWith(staticError)`, and the `withCallable` / `withGet` / `withPost` verbs
all bake a fixed body at config time. That cannot model a call whose **server
side-effect the client reads back** — the motivating case is `createOffer`,
which must return `{offerId}` *and* atomically write `offers/{offerId}` to
Firestore, where the id is chosen server-side.

Because `StubOutcome` is `sealed`, adding a leaf is a compiler-checked change
across exactly three switch sites — [`callable_client.dart:67`](../../packages/cascade_firebase/lib/src/callable_client.dart#L67),
[`fake_http_client_adapter.dart:32`](../../packages/cascade_dio/lib/src/fake_http_client_adapter.dart#L32),
and [`registry_mock_client.dart:17`](../../packages/cascade_http/lib/src/registry_mock_client.dart#L17) —
plus new `withCallableHandler` / `withGetHandler` / `withPostHandler` verbs. The
registry, sequencing (`Stub.next`), latency, recording, and fail-fast are all
untouched: a handler is just one more outcome in an outcome list.

## Why This Approach

The sealed leaf is the only real design *given* — it's the minimal, type-safe way
to extend the outcome model, and the compiler enforces that no switch site is
missed. The three open forks were resolved toward the **smallest core surface
that respects the package boundary**:

- The core `RespondWithHandler` stays **transport- and Firebase-agnostic**: it
  receives a `BoundaryRequest` and returns a `BoundaryResponse`. It knows nothing
  about Firestore. This keeps `cascade_core` (Layer A) transport-free, exactly as
  the existing static leaves are.
- Firestore access is reconciled **entirely inside `cascade_firebase`** by
  late-binding through the existing per-builder `_FirebaseConfig` Expando — no new
  context concept leaks into core.
- The verb set ships **symmetric** (callable + HTTP handler verbs) because the
  sealed change already forces every switch site; the HTTP verbs are a few lines
  each over the same leaf.

An explicit `HandlerContext` threaded from adapter → core was rejected: it forces
`cascade_core` to carry a context type that only means anything for the Firebase
transport, i.e. machinery for no extra capability. A `FutureOr<StubOutcome>`
return (handler decides respond-vs-fail dynamically) was rejected as YAGNI for now
— `createOffer` only needs the success path, and non-2xx is already expressible as
a `BoundaryResponse`.

## Key Decisions

- **Core leaf — `RespondWithHandler(handler, {latency})` in
  [`stub.dart`](../../packages/cascade_core/lib/src/registry/stub.dart).** The
  handler is `FutureOr<BoundaryResponse> Function(BoundaryRequest request)`.
  Extends `StubOutcome` so it inherits per-outcome `latency` and slots into
  sequences unchanged. `resolve()` stays synchronous (it returns the outcome);
  the **handler runs in the adapter's switch arm, after the awaited latency**.

- **Firestore access — late-bind via `_FirebaseConfig` (chosen).**
  `withCallableHandler` lives in `cascade_firebase` and exposes a Firestore-aware
  signature `(BoundaryRequest request, FakeFirebaseFirestore firestore)`. It
  registers a core handler that reads the built Firestore off the shared
  per-builder `_FirebaseConfig` **lazily at call time**. `useFirebase()`'s install
  step stores the `FakeFirebaseFirestore` on `_config` when it creates it at build
  time. Because the handler body executes during the running test (post-build),
  the instance is always present. **Verb order is irrelevant** —
  `withCallableHandler` and `useFirebase()` can be called in either order since
  both touch the same Expando entry.

- **Handler output — `FutureOr<BoundaryResponse>` (chosen).** Symmetric with
  `RespondWith`, so HTTP handlers can set status/body/headers. The callable verb
  layers an ergonomic wrapper on top: the user returns a plain `Object?` body and
  the verb wraps it as `BoundaryResponse(statusCode: 200, body: ...)`, matching
  how `FakeCallableClient.call` already does `response.body as T`. Dynamic
  transport/callable *failure* from a handler is deferred (YAGNI).

- **Verb surface — callable + HTTP handler verbs (chosen).**
  - `withCallableHandler(name, (request, firestore) async => body)` in
    `cascade_firebase` — the P0 need.
  - `withGetHandler(path, (request) async => Res(...))` and
    `withPostHandler(path, (request) async => Res(...))` in `cascade_core`'s
    `TestHarnessBuilder`. These are transport-pure (no Firestore) and return the
    existing `Res` ergonomic type, consistent with `withGet`/`withPost`; the verb
    maps `Res → BoundaryResponse` exactly as `_registerHttp` does today.

- **Single-invocation guarantee (correctness).** Each adapter must invoke the
  handler **once** per resolution and reuse the result — a handler that writes
  Firestore must not run twice. The dio and http switch *expressions* today would
  reference the response in two places (`jsonEncode(body)` and `statusCode`), so
  those two sites convert to a `switch` **statement** (or bind `final response =
  await handler(request)` before building) to await once. The callable site stays
  a single-expression arm. `registry_mock_client` additionally captures the
  mapped request in a local (`final boundaryRequest = _mapRequest(request)`) so it
  can be passed to the handler.

## Scope & Non-Goals

**In scope:** the `RespondWithHandler` core leaf; the three switch-site arms;
`withCallableHandler` (Firebase, Firestore-aware); `withGetHandler` /
`withPostHandler` (core, transport-pure); late-bind of `FakeFirebaseFirestore`
onto `_FirebaseConfig`; unit tests for the new leaf and each verb; and a
`createOffer`-style demo/acceptance proof (compute id → write `offers/{id}` →
return `{offerId}` → app reads the doc back).

**Non-goals (YAGNI):**
- No `HandlerContext` type in core.
- No `FutureOr<StubOutcome>` return / dynamic fail-from-handler (non-2xx is
  already a `BoundaryResponse`; a callable that must *throw* dynamically is a
  separate, later ask).
- No Auth/Storage handles passed to the handler yet — Firestore only, per the P0
  case. Additive later if a real need appears.
- No streaming/handler-per-emission interaction (that's the separate streams
  effort).

## Constraints & Risks

- **`FutureOr` import.** `stub.dart` gains `dart:async` and a `boundary_request`
  import; the leaf's handler type references `BoundaryRequest`, which core already
  owns.

- **Handler-without-`useFirebase()` misuse.** If `withCallableHandler` is used but
  `useFirebase()` never ran, `_config.firestore` is null at call time. Fail fast
  with a descriptive `StateError` ("withCallableHandler requires useFirebase()")
  rather than a raw null-check crash — mirrors the `TestHarnessBuilder.harness`
  pre-build guard.

- **Async timing.** The handler is awaited inside the adapter after the latency
  delay; Firestore writes it performs commit on a later microtask (the review I1 /
  `buildHarnessAsync` lesson). The acceptance test reads the doc back through the
  app under test and `pumpUntil`s the resulting UI — it must not assert
  synchronously against Firestore immediately after the call resolves.

- **Layer isolation preserved.** Core leaf is transport-free; Firestore knowledge
  stays in `cascade_firebase`; the demo owns the `createOffer` feature and keys.
  No new dependency edges.

- **Recording unaffected.** `recorder.record(request)` runs in `resolve()` before
  the handler executes, so `expectCalled*` assertions see handler-backed calls
  identically to static ones.

- **Sequencing & latency parity.** A handler can appear anywhere in an outcome
  sequence and honors per-outcome `latency`, because it is an ordinary
  `StubOutcome` — verify with a mixed sequence test (`[RespondWith, handler]`).

## Success Criteria

- **CR1-S1** — A `withCallableHandler('createOffer', ...)` computes an id, writes
  `offers/{id}` to the fake Firestore, and returns `{offerId: id}`; the app reads
  the freshly written doc back. Proven by a `demo_dio_firebase` acceptance test.
- **CR1-S2** — All three adapters compile against the new sealed leaf and invoke
  the handler **exactly once** per resolution (asserted by a handler with an
  observable side-effect counter).
- **CR1-S3** — `withGetHandler` / `withPostHandler` compute a response from the
  request (e.g. echo a path/query param) — covered by `cascade_core` unit tests.
- **CR1-S4** — A handler participates correctly in a sequence and honors per-
  outcome latency (`cascade_core` unit test).
- **CR1-S5** — `withCallableHandler` without `useFirebase()` throws a descriptive
  `StateError`.
- **CR1-S6** — `dart analyze` clean across all touched packages; existing tests
  (including `demo_http` robot parity) stay green.

## Open Questions

- **HTTP handler signature — `Res` vs `BoundaryResponse` return.** Leaning `Res`
  for surface symmetry with `withGet`/`withPost`; confirm in planning (trivial
  either way — the core leaf speaks `BoundaryResponse` regardless).
- **Callable verb generics.** Whether `withCallableHandler` is generic
  (`<T>`) or just takes an `Object?`-returning fn like `withCallable`. Leaning
  non-generic for parity; the cast to `T` already lives in
  `FakeCallableClient.call<T>`.
- **Demo feature shape.** `createOffer` as a new `offers` feature vs folding into
  an existing one; and whether the app reads the written doc via a one-shot get or
  a `.snapshots()` listener (ties into the streams work). Decide in planning.
- **Switch-site style.** Confirm the dio/http sites move to a `switch` statement
  (cleanest single-await) vs binding `final response` before a preserved switch
  expression — an implementation-detail call for the plan.
