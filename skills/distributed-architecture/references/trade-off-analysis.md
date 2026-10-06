# Building a trade-off analysis

Use this file when you must compare options for a boundary, a data design, or a workflow, and then record the decision.

No numbers are needed. A qualitative matrix is enough and is often more honest. Invented scores look precise and hide guesses.

## Method

1. **State the decision as an outcome.** Write "How should billing keep its data?" and not "Should we use microservices?"
2. **Map what is tied together.** List code, data, deploy, runtime calls, and teams that touch the decision. Each tie is a cost of change.
3. **List the forces.** Include the business goals and the system qualities in play, such as consistency, availability, cost, speed of change, and operating load.
4. **Write options that do not overlap.** Each option must differ in a real way. Together they should cover all sensible choices. Include "do nothing" and "keep together".
5. **Profile each option alone.** Write what it gives, what it costs, and what it assumes. Do this before you compare options. It prevents a favorite from shaping the notes.
6. **Run scenarios.** Test each option against normal load, a typical change, a failure, and a cross-boundary operation.
7. **Compare.** Use a table with plain words such as better, worse, same, and unknown. Add one line of reason per cell.
8. **Reduce to a few choices.** Present two or three options to the decision makers, with the cost of each in business terms.
9. **Decide and record.** Write an ADR.
10. **Add checks.** Add a fitness function or a metric for each risk you accepted.
11. **Set a review trigger.** State what change in facts would reopen the decision.

## Matrix layout

Put options in columns and forces in rows. Use words. Use "unknown" when you lack data, and list how to find it out.

## ADR template

- **Title:** a short decision statement.
- **Status:** proposed, accepted, or superseded.
- **Context:** the problem, the forces, and the facts that matter.
- **Options considered:** each in one or two lines.
- **Decision:** what you chose.
- **Consequences:** what you gain, what you give up, and what new work appears.
- **Checks:** the tests, metrics, or fitness functions that guard the decision.
- **Review trigger:** the event or date that reopens it.
- **Owner:** the person or team that answers for it.

## Worked example: give billing its own service and database

**Decision:** Should billing leave the main application and own its own database?

**Context (assumed):** A single application handles orders, customers, and billing in one relational database. Billing logic changes often because of tax and plan rules. Orders are stable. Payment data has stricter audit rules. An order and its invoice are created together today in one transaction.

**Ties:** billing code calls customer and order classes. Billing tables join to orders and customers. Invoice creation shares the order transaction. One team owns all three areas.

**Options:**

- **A. Keep together.** Add a billing module with enforced boundaries. Keep one database.
- **B. Separate service, shared database.** Billing runs as its own service but reads and writes the shared schema.
- **C. Separate service, own schema or database.** Billing owns its tables. It gets order and customer data by a call or a copy.
- **D. Separate service with own database and a saga** for order-to-invoice. Order confirms first, then billing creates the invoice.

**Profiles:**

- **A.** Gives fast change in billing code with low risk. Costs: shared release train, shared scaling, and no audit isolation. Assumes the team can hold the module line.
- **B.** Gives independent deploys of billing code. Costs: schema changes still affect other parts, and the shared data keeps the audit issue. It looks like a split but acts like one unit.
- **C.** Gives deploy freedom, audit isolation, and clear ownership. Costs: joins to orders and customers disappear. Order and invoice no longer share a transaction. Billing must handle stale customer data.
- **D.** Adds eventual consistency on top of C. An order may exist for a short time without an invoice. Costs: saga state, retries, compensation if the invoice fails, and a repair owner.

**Scenarios:**

| Scenario | A | B | C or D |
|---|---|---|---|
| Normal order | Simple, one transaction | Simple | Extra call or message |
| Tax rule change | Ship with all code | Ship alone, but check schema effects | Ship alone |
| Billing database outage | Whole application affected | Whole application affected | Orders can continue under D. Orders may block under C if the call is sync |
| Invoice fails after order | Roll back both | Roll back both | Needs compensation or retry. Cancel the order or hold it as pending |
| Audit of payment data | Hard to limit access | Hard to limit access | Easy to limit access |

**Comparison in words:**

- Change speed in billing: A fair, B good, C and D best.
- Consistency of order and invoice: A and B best, C good, D weaker.
- Fault isolation: A and B weak, C fair, D best.
- Audit isolation: A and B weak, C and D strong.
- Build and run cost: A low, B low, C medium, D high.

**Outcome choices for stakeholders:**

1. Stay with A now. Low cost. Revisit when audit or deploy pain grows.
2. Move to C with a sync call for customer data and one transaction boundary kept for order and invoice. Pick this if audit rules are the main driver and the team accepts a short delay on invoices.
3. Move to D if billing must stay up when orders fail, or the reverse, and the team can run a saga.

**Sample decision:** Choose A now with a hard module line and a check that blocks cross-module table access. This prepares the data for option C. Review when a regulator asks for audit isolation, when billing deploys block other releases twice in a quarter, or when billing load needs separate scaling. Avoid B. It pays the split cost and keeps the coupling.

**Checks to add:** a dependency test that fails if non-billing code touches billing tables, and a metric for release delays caused by billing.

## Common mistakes

- Comparing options before profiling each one alone.
- Scoring with numbers that no one can defend.
- Leaving out "keep together" as an option.
- Listing benefits of the split and not the new work it creates.
- Stopping at a table. Always end with the record, the checks, and the review trigger.
