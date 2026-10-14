---
name: architecture
description: Use when choosing or judging a software architecture or a module interface, such as monolith vs modular monolith, styles, trade-offs, fitness functions, seams, bounded contexts, or ADRs. Gives a decision workflow and trade-off checklists.
---

# Architecture decisions

Use this skill to pick or judge a system structure. Work through the seven steps in order. Write down the output of each step. Do not name a style before step 3.

For the interface of a single module, skip the seven steps. Read `references/deep-modules.md` and follow it.

## 1. Find the driving characteristics

A characteristic is a quality the system must show, such as speed, uptime, or ease of change. Characteristics, not features, shape the structure.

1. Read the requirements. Mark every phrase that implies a quality. "Millions of shoppers on sale day" implies elasticity. "Auditors must trace every change" implies auditability.
2. Read the domain. Ask what hurts the business most when it fails. Ask who the users are and how they spike.
3. Add the implicit ones. Almost every system needs security, basic reliability, and some level of maintainability, even when nobody says so.
4. Cut the list to 3 to 7 items. Each extra item adds cost and pulls the design in another direction.
5. Rank the top 3. If the team cannot agree on the top 3, stop and ask the business.

Read `references/characteristics.md` when you need a definition or a way to measure one.

## 2. Find the scope: architecture quanta

An architecture quantum is a part that deploys on its own, holds its own data, and has its own characteristic needs. Count the quanta.

- Ask whether one part needs to scale, fail, or release on a different schedule from the rest. If no part does, you have one quantum.
- One quantum means a single deployable system is enough. Several quanta mean you need a distributed design for those parts only.
- Check the data. Two services that share one database and release together are one quantum, not two.
- Treat each quantum as its own small architecture problem with its own top 3.

## 3. Pick candidate styles and compare trade-offs

1. Choose at most three candidate styles. Use `references/styles.md` to find them.
2. Start with the simplest style that could meet the top 3 characteristics. Move to a more complex style only when you can name the characteristic that forces it.
3. Score each candidate in plain words for each top characteristic: good fit, workable, or poor fit.
4. Write the price of each candidate: cost, team skill needed, operational load, and testing effort.
5. Drop any candidate that is a poor fit for a top-3 characteristic.
6. Pick the survivor with the lowest price. Record what you gave up.

## 4. Choose the partitioning

Partitioning decides how you cut the code into top-level parts.

- **Technical partitioning** cuts by role, such as UI, logic, and data. It suits systems where most changes touch one role at a time.
- **Domain partitioning** cuts by business capability, such as billing, catalog, and shipping. It suits systems where most changes touch one capability across all roles.
- Look at your last 20 change requests. Count how many stay inside one role and how many stay inside one capability. Cut along the more common axis.
- Draw each domain part as a bounded context with its own model and its own vocabulary. Keep the data behind the part private.
- Measure cohesion inside a part and coupling between parts. Aim for high cohesion and few, narrow links.

For the monolith question, read `references/monolith-vs-modular.md`.

## 5. Protect the choice with fitness functions

A fitness function is an automated check that tells you whether the design still meets a characteristic. Without checks, the design erodes.

1. For each top characteristic, write one check. Use a number and a threshold.
2. Run the check in the build pipeline or on a schedule.
3. Fail the build or raise an alert when the threshold breaks.
4. Add structure checks too. Examples: no cycles between modules, no import from a private package, no call from the UI layer straight to the database.
5. Review thresholds every quarter. Change a threshold only through an ADR.

## 6. Record the decision as an ADR

Write one short record per significant decision. Use this template:

```
Title: short noun phrase
Status: proposed, accepted, superseded by <id>
Context: the forces at play, in 3 to 6 lines
Decision: what we will do, in active voice
Consequences: what gets better, what gets worse
Alternatives: what we rejected and why
Fitness functions: the checks that guard this decision
```

Keep each ADR under one page. Record the why. The code already shows the how. See `references/decisions-and-risk.md` for more.

## 7. Name the risks

1. List the areas where the design could fail. Include unproven technology, single points of failure, and skills the team lacks.
2. Rate each risk by likelihood and impact on a 3-point scale. Multiply the two.
3. Ask several people to rate alone first, then compare. A large gap between raters shows hidden knowledge.
4. Assign an owner and a mitigation to every high risk.
5. Re-run this step after each major change.

Read `references/decisions-and-risk.md` for the grid and the group method.

## Rules of thumb

- Everything is a trade-off. If you see no downside, you have not looked hard enough.
- The reason for a choice matters more than the mechanics of it.
- Prefer the least complex style that meets the top characteristics.
- Start with a modular monolith. Split out a part only when it needs its own scaling, release rhythm, or fault isolation.
- Distributed systems cost more to build, test, run, and debug. Pay that cost only for a named benefit.
- Default to synchronous calls. Use asynchronous messaging when you need decoupling in time or you must absorb bursts.
- Cut along the axis where change happens most.
- Share data through a clear contract, not through a shared table.
- An architecture without checks is only a wish.
- Review the decision when the context changes. A good decision can expire.

## Reference files

- `references/styles.md`: read when you compare candidate styles in step 3.
- `references/characteristics.md`: read when you define or measure a characteristic in steps 1 and 5.
- `references/decisions-and-risk.md`: read when you write an ADR or run a risk session in steps 6 and 7.
- `references/monolith-vs-modular.md`: read when the question is whether to stay a monolith or become a modular monolith.
- `references/deep-modules.md`: read when you design a module's interface, decide where a seam goes, or compare interface designs.

## Further reading

Inspired by "Fundamentals of Software Architecture" (2nd edition) by Mark Richards and Neal Ford.
