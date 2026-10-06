# Stay a monolith or become a modular monolith?

A plain monolith has no enforced internal borders. A modular monolith still deploys as one unit, but it has domain modules with hard borders. Use the checklist below.

## Step A: Check the signs of pain

Answer yes or no.

1. Do most changes touch many unrelated areas of the code?
2. Does a small fix often break a distant feature?
3. Do two teams block each other in the same files?
4. Does a new developer need weeks to find where a rule lives?
5. Do tests need the whole system to check one rule?
6. Does one area of the code change much more often than the rest?

If you answer yes to three or more, internal borders will help. Go to step B.
If you answer yes to fewer than three, keep the current shape. Add the checks in step D only.

## Step B: Check whether a split is needed at all

Answer yes or no.

1. Does one part need its own scaling that the rest does not?
2. Does one part need a different release schedule?
3. Does one part need to survive when the rest fails?
4. Does one part need a different runtime or language?
5. Does a different team own it with a strong wish for independence?

If you answer no to all five, do not split into services. Choose the modular monolith.
If you answer yes to some, split out only those parts. Keep the rest as a modular monolith.

## Step C: Build the modules

1. List the business capabilities. Use words the business uses.
2. Give each capability a module with a bounded context. Each module owns its model and its data.
3. Place all roles of one capability inside its module: interface, logic, and data access.
4. Expose a small public interface for each module. Mark everything else private.
5. Forbid direct access to another module's tables or internal classes.
6. Let modules talk through calls to the public interface, or through in-process events.
7. Move shared code into a small, stable shared kit. Keep business rules out of it.
8. Migrate in small steps. Pick the module with the clearest border first.

## Step D: Guard the borders

Add these checks to the build.

- No dependency cycle between modules.
- No import of a private package from another module.
- No query that joins tables from two modules.
- A limit on the number of links between any two modules.
- A build time and a test time that stay under a set limit.

## Step E: Set exit triggers

Write down the facts that would make you split a module out later. Examples:
- The module needs ten times the capacity of the rest.
- The module needs a release every day while the rest releases monthly.
- A team grows so large that it needs its own pipeline.

Because the borders already exist, the split costs far less later.

## Common traps

- Naming folders as modules without enforcing borders.
- Keeping one shared data model for all modules.
- Putting too much into the shared kit.
- Splitting into services because it is fashionable, with no named benefit.
- Cutting modules by technical role instead of business capability.
