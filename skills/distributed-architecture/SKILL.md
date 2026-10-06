---
name: distributed-architecture
description: Use when splitting or joining services, such as service granularity, data ownership, distributed transactions, sagas, contracts, or coupling. Gives a decision workflow and trade-off checklists.
---

# Distributed architecture: a decision workflow

Use this skill when a team asks "should we split this?" or "how do these services share data?" Work through the steps in order. Stop at the first step that settles the question.

## 1. Decide if a split is justified

Name the concrete driver. Accept only drivers that you can measure or observe.

- **Independent scaling:** one part needs far more capacity than the rest.
- **Deploy cadence:** one part changes weekly and the rest changes yearly.
- **Fault isolation:** a failure in one part must not take down the rest.
- **Team ownership:** separate teams block each other in one codebase.
- **Security boundary:** one part handles data with stricter rules.

If no driver applies, keep the code together. Improve internal modules first. A split adds network calls, data copies, and new failure modes.

## 2. Find the seams

Weigh forces for and against a split at the same boundary.

- **Forces for a split:** weak cohesion, uneven change rate, uneven load, different fault tolerance, security needs.
- **Forces for a join:** one transaction must cover both parts, workflows call each other in a tight chain, both parts share much domain code, data relationships cross the line.

One hard business rule that needs a single transaction often beats several mild reasons to split. Read `references/granularity.md` when the forces are unclear.

## 3. Decide data ownership

- Give each table exactly one writing service. Writing creates ownership. Reading does not.
- Many readers are normal. Many writers are the problem.
- If two services write one table, pick one option: merge the services, give one service the writes, split the table by column or rows, or move the shared data to a dedicated owner service.

Read `references/data.md` when you must split a database or settle a write conflict.

## 4. Choose how services read data they do not own

| Option | Choose when | Main cost |
|---|---|---|
| Call the owner | Data must be fresh and call volume is low | Latency and owner outage |
| Replicated copy | Reads are frequent and slight staleness is fine | Sync logic and stale data |
| Distributed cache | Data is small and hot | Memory use and cold-start risk |
| Shared data domain | Services need joins and one data model | Tight schema coupling and wide access |

Pick by freshness need, call rate, and outage tolerance. Do not pick by habit.

## 5. Choose the transaction approach

1. Try to keep each business operation inside one transaction boundary. Move the boundary, merge services, or both.
2. If you cannot, accept eventual consistency and design a saga.
3. Pick three settings: sync or async messages, atomic or eventual consistency, orchestrated or choreographed coordination.
4. Define compensation for every step that can fail late.
5. Assign an owner for stuck workflows.

Orchestration suits complex flows with many error paths. Choreography suits short, simple, high-volume flows. Read `references/sagas.md` before you design any saga.

## 6. Pick contract strictness

- **Strict contracts** (typed schemas, fixed fields) catch errors early. They force services to change together.
- **Loose contracts** (name-value pairs, optional fields) allow independent change. They move checks into tests and runtime.
- Send each consumer only the fields it needs.
- With loose contracts, add consumer-driven contract tests. Each consumer states what it reads. The provider build fails when a change breaks that.

## 7. Handle shared code

| Option | Choose when |
|---|---|
| Copy the code | It is tiny and almost never changes |
| Shared library | It changes at a moderate rate and all services share a platform |
| Shared service | It changes often or services use many languages. Accept runtime coupling |
| Sidecar or service mesh | It is an operational concern such as logging, tracing, or security. Never put domain logic there |

Decide with change history and the most critical caller. Do not decide by counting duplicate lines.

## 8. Write the trade-off analysis and the ADR

State the decision, the options, the forces, and what each option gives up. Run normal, change, and failure scenarios. Then record an ADR with context, decision, consequences, owner, and a review trigger. Add a fitness function (an automated check) for each rule that must hold. Read `references/trade-off-analysis.md` for a method and a worked example.

## Rules of thumb

- There are no best practices. There are trade-offs for your context.
- Choose the least worst option. Every option has a cost.
- Data is the hardest part to split. Plan it first.
- Prefer one transaction boundary per business operation.
- Every removed coupling point comes back as new work. Name that work.
- Separate processes that share a database are still one deployable unit in practice.
- Fewer, larger services are often the right start. Split when a driver appears.
- An "eventual" step with no deadline and no repair owner is a bug.
- Record decisions. A decision without a recorded reason gets reversed by accident.

## References

- `references/data.md`: read when you split a database, settle a write conflict, or pick a read option.
- `references/sagas.md`: read when a business operation spans services and one transaction cannot cover it.
- `references/granularity.md`: read when you need questions to test a split or a join.
- `references/trade-off-analysis.md`: read when you must compare options and write a decision record.

Further reading: *Software Architecture: The Hard Parts* by Neal Ford, Mark Richards, Pramod Sadalage, and Zhamak Dehghani.
