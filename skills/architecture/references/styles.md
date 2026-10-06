# Architecture styles: quick judgments

These are qualitative judgments. Adjust them to your team and context. Each entry gives the idea, the fit, the pain, and the usual failure.

## Layered
- **What:** Horizontal slices such as presentation, business, and data. Requests move down through the slices.
- **Good fit:** Small systems, tight budgets, early products, teams that are new to architecture.
- **Hurts when:** The system grows and each change touches every layer. Scaling is all or nothing.
- **Typical failure:** Layers that only pass calls along and add no value. If most requests behave this way, the style is wrong.

## Modular monolith
- **What:** One deployable unit, split inside into modules that follow business domains. Each module hides its data and exposes a small interface.
- **Good fit:** Most new products, teams of one to a few dozen, domains still being learned.
- **Hurts when:** One module needs a very different scale, runtime, or release pace. Also hurts when the build gets slow.
- **Typical failure:** Modules that reach into each other's tables or classes. The result is a tangled single block.

## Pipeline
- **What:** A chain of steps. Each step takes input, does one job, and passes output on. Some steps produce, some transform, some test, some consume.
- **Good fit:** Data conversion, batch jobs, build tools, report generation.
- **Hurts when:** Work needs back-and-forth interaction or branching state.
- **Typical failure:** Steps that do several jobs, so they cannot be reused or reordered.

## Microkernel
- **What:** A small core with the basic flow, plus plug-ins that add features. Plug-ins register with the core.
- **Good fit:** Products that users extend or customize, such as IDEs, rule engines, and tools with many variants.
- **Hurts when:** Plug-ins need to talk to each other a lot, or the core keeps changing.
- **Typical failure:** A core that absorbs plug-in logic until it is no longer small. A second failure is a plug-in contract that changes every release.

## Service-based
- **What:** A handful of coarse services, each covering a large domain area. The UI is often one app. The services often share a database.
- **Good fit:** Teams that want some distribution benefits without a heavy cost. Good when transactions across domains still matter.
- **Hurts when:** Many teams collide on the shared database schema. Scaling a tiny hot spot is hard because services are large.
- **Typical failure:** Splitting services into many fine pieces without splitting the data, which gives the cost of both worlds.

## Event-driven
- **What:** Parts communicate by emitting and reacting to events. No part waits for a reply. Two flavors exist: parts react to each other freely, or a central mediator drives the flow.
- **Good fit:** Bursty load, reactive flows, systems with many consumers of the same fact, real-time feeds.
- **Hurts when:** The business needs one clear, ordered, all-or-nothing result. Tracing a flow is hard. Error handling is harder.
- **Typical failure:** Too many tiny events with thin payloads, so consumers must call back for data. Another failure is lost or duplicated events with no plan.

## Space-based
- **What:** Processing units hold data in memory grids. A data layer writes to the database in the background. There is no central database in the request path.
- **Good fit:** Extreme and unpredictable traffic spikes, such as ticket sales or auctions.
- **Hurts when:** Data is large, strongly consistent, or rarely under load. It is costly and hard to test.
- **Typical failure:** Two units change the same data faster than it replicates. Users then see stale or conflicting values.

## Orchestration-driven SOA
- **What:** A central bus and orchestrator coordinate large, shared enterprise services. Reuse was the main goal.
- **Good fit:** Mostly historical. It may fit when you must glue many old packages and systems into one flow.
- **Hurts when:** A change in one shared service ripples to all users. The orchestrator becomes a bottleneck and a team bottleneck.
- **Typical failure:** Reuse pressure that creates huge shared services that nobody can change safely.

## Microservices
- **What:** Many small services, each owning its domain, its data, and its release. Services share nothing and talk through contracts.
- **Good fit:** Large organizations with strong automation, many teams, and parts that truly need separate scaling or release.
- **Hurts when:** The team is small, the domain is unclear, or operations are immature. Cross-service transactions are painful.
- **Typical failure:** Services cut too fine, or cut along database tables. They call each other so often that they behave as one system with network delay.
