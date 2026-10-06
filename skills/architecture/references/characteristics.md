# Characteristics: definitions and checks

Each line gives a plain definition and one automated check. Pick numbers from your own business need.

## Operational

- **Performance:** How fast the system answers. Check: a load test that fails the build when the 95th percentile response time passes a set limit.
- **Scalability:** How well the system handles more users over time. Check: a test that doubles load and confirms response time grows less than a set ratio.
- **Elasticity:** How quickly the system copes with sudden bursts. Check: a spike test that confirms response time recovers within a set number of seconds.
- **Availability:** The share of time the system works. Check: a monitor that tracks uptime against a monthly target and alerts on a breach.
- **Reliability:** How often operations finish correctly. Check: the failed-request rate stays below a set percent in production.
- **Recoverability:** How fast service returns after a disaster. Check: a scheduled restore drill that must finish inside the target time.
- **Fault tolerance:** How the system behaves when a part fails. Check: a chaos test that stops one component and confirms users still get answers.

## Structural

- **Maintainability:** How easy it is to fix and adjust the code. Check: a limit on complexity per function and on file size, enforced by a static tool.
- **Modularity:** How well code splits into independent parts. Check: a test that fails when modules form a dependency cycle.
- **Cohesion:** How closely the contents of a part belong together. Check: a report of classes that change for unrelated reasons, reviewed each release.
- **Coupling:** How much parts depend on each other. Check: a count of cross-module imports that fails above a set limit.
- **Deployability:** How easy and safe it is to ship. Check: pipeline time from commit to production stays under a set limit.
- **Testability:** How easy it is to prove the code works. Check: coverage and mutation score above a set floor on core logic.
- **Evolvability:** How easy it is to add or change features. Check: lead time for a typical change stays under a target.
- **Portability:** How easily the system runs on another platform. Check: the full test suite runs in a second environment on every release.
- **Interoperability:** How well the system works with others. Check: contract tests against each partner interface.
- **Configurability:** How much behavior changes without code edits. Check: a test that flips each setting and confirms the system starts.

## Cross-cutting

- **Security:** Protection of data and access. Check: dependency scans, secret scans, and an access test in the pipeline, with zero known critical findings.
- **Privacy:** Control over personal data. Check: a scan that finds personal fields outside approved stores.
- **Auditability:** The ability to trace who did what. Check: a test that confirms every write action creates a log entry.
- **Observability:** How well you can see inside a running system. Check: every service emits traces and a health signal, verified by a startup test.
- **Usability:** How easy users find the system. Check: task completion time in a regular user test.
- **Accessibility:** Use by people with disabilities. Check: an automated accessibility scan with zero serious issues.
- **Cost:** What the system costs to build and run. Check: a monthly spend report with an alert at a set budget line.
- **Feasibility:** Whether the plan fits time, budget, and skills. Check: a review at each milestone that compares the plan with real progress.
- **Agility:** How fast the organization responds to change. Check: the combined time for build, test, and release stays under a target.

## Tips

- Do not chase every item. Most items fight with others. Speed often trades against security checks, and elasticity often trades against cost.
- Make each item measurable before you rely on it. "Fast" is not a requirement. "95 percent of searches finish in under one second" is.
- Define each term the same way across the team. Write the definitions in the ADR context.
