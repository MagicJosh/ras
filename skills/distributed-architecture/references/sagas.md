# Designing a saga

Use this file when one business operation touches several services and no single database transaction can cover it.

First ask: can you avoid this? Merge the services, or move the boundary so one service owns the whole operation. A saga is the fallback, not the first choice.

A saga is a chain of local transactions. Each step commits in one service. If a later step fails, earlier steps need an undo action. The system is not consistent at every moment. It becomes consistent when the saga ends.

## The three dimensions

Make three separate choices. Each choice changes the cost of the design.

### 1. Communication: sync or async

- **Sync:** the caller waits for the answer. The flow is easy to follow and to debug. The caller is blocked, and one slow service slows the chain.
- **Async:** the caller sends a message and moves on. Services stay loosely tied in time. You now need message correlation, retries, duplicate handling, and durable state for each in-flight operation.

### 2. Consistency: atomic or eventual

- **Atomic:** the saga tries to behave like one transaction. If any step fails, all steps are undone before anyone sees a result. The caller sees all or nothing. The cost is coordination work, longer waits, and more undo logic.
- **Eventual:** each step commits at once. Other parts of the system may see a half-finished state. The data converges later. The cost is that every reader must cope with the in-between state.

### 3. Coordination: orchestrated or choreographed

- **Orchestrated:** one service holds the workflow. It calls the steps, tracks state, and handles errors. The flow is visible in one place. The orchestrator can become a bottleneck and a single point of failure. It also adds coupling to every step.
- **Choreographed:** no central owner. Each service reacts to events and emits new ones. This gives high throughput and low central coupling. The workflow lives in many places. Error handling gets hard as branches grow.

## Which combinations make sense

Eight combinations exist. Do not memorize them. Judge each by asking what it costs and what it buys.

### Combinations that usually work

- **Sync, atomic, orchestrated.** The orchestrator calls each step and undoes the earlier ones on failure. It is the most familiar shape. It suits flows with real business rules and a user waiting. It is slow and the orchestrator holds much state.
- **Async, eventual, orchestrated.** The orchestrator sends commands and waits for replies. It tracks state and retries. This suits complex flows with many error paths. It scales better than the sync form. The orchestrator must survive restarts, so it needs durable state.
- **Async, eventual, choreographed.** Events flow from service to service. It suits short, simple, high-volume flows with few failure branches. Add a clear event schema and a monitor for stuck work.
- **Sync, eventual, orchestrated.** Easy to build when each step is fast. It works when you accept in-between states but still want a clear flow.

### Combinations that need great care

- **Atomic and choreographed together.** Atomic needs a coordinator to undo steps in the right order. Choreography has none. Services must send undo events to each other. The flow becomes a web of events that is hard to test. Avoid unless the flow is very short.
- **Sync, atomic, choreographed.** Each service calls the next one and holds the caller while it waits. An error deep in the chain must travel back up the chain with undo work at each level. Many services end up knowing the whole flow.

### Common traps

- Using choreography for a flow with many error paths. Teams then rebuild a hidden orchestrator in each service.
- Using an orchestrator for every flow by default. Simple flows then pay for a central bottleneck.
- Picking async only for speed, without a plan for duplicates and lost messages.
- Calling the design "eventual" without a deadline. Work that never finishes is a silent data bug.
- Splitting a flow across so many services that no one can say where a request is.

## Compensation

Compensation is the undo action for a committed step. It is a new business action. It is not a database rollback.

- Define a compensation for every step that can be followed by a failure. A final step often needs none.
- Make each compensation safe to run twice. Retries will happen.
- Some effects cannot be undone: an email already sent, a payment already settled, a shipment already out. Order the steps so that irreversible steps come last. When that is not possible, plan a correction action such as a refund or an apology message.
- Undo steps can fail too. Define what happens then: retry with a limit, then raise an alert to a person. Name the owner of that alert.
- Think about who saw the intermediate state. A reader may have acted on data that you now reverse.

## State management

A saga needs a record of where it stands.

- Store the saga state in durable storage. Memory alone loses it on restart.
- Record: saga id, current step, data needed for undo, start time, and a status such as running, compensating, done, or failed.
- Give every message a correlation id. Give every step an idempotency key so a repeated message does no harm.
- Set a deadline for each saga. A job scans for sagas past the deadline and starts repair.
- Expose the status to the user and to support staff. A user who sees "pending" can wait. A user who sees nothing will retry and create duplicates.
- For choreographed flows, build a separate monitor that reads the events and rebuilds the status. No service holds the full picture otherwise.

## Choosing quickly

1. Does the flow have more than two or three error branches? Lean to orchestration.
2. Is the flow short and the volume very high? Lean to choreography.
3. Must the user see an all-or-nothing result? Lean to atomic and accept the cost, or merge services.
4. Can the user accept "pending, we will confirm"? Lean to eventual.
5. Do you lack tools for durable state and retries? Use sync until you have them.

Write the choice and its costs in an ADR. Add tests for failure at each step, duplicate delivery, and a failed compensation.
