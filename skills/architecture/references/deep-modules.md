# Deep modules

Read this file when you design a module, change a module's interface, or decide where a test seam goes.

## Terms

- **Module**: any unit of code that callers use through an interface, such as a function, a class, a package or a service.
- **Interface**: all that a caller has to know to call the module correctly. That is the types, and also the call order, the errors, the limits and the invariants.
- **Deep module**: a small interface in front of a lot of behavior. A **shallow module** has an interface almost as large as what it hides.
- **Seam**: the place where callers and tests meet the module, and where you can swap the implementation.

## Checks

1. **Delete it in your head.** Inline the module into its callers. If the complexity spreads over many callers, the module earns its place. If nothing gets harder, it only passes calls through. Merge it.
2. **Count the implementations.** A seam with one implementation is a guess. Add an interface or a port only when two implementations exist, such as production and test.
3. **Test where callers call.** Tests cross the same seam as callers. If a test must reach past the interface, the module has the wrong shape.
4. **Pull complexity down.** Prefer fewer entry points, fewer parameters and good defaults, so that each caller does less.
5. **Take dependencies in.** Pass a dependency in instead of creating it inside. Return a result instead of changing an argument.

## Dependencies and tests

- Code with no I/O: test it through the interface directly.
- A dependency with a local stand-in, such as an in-memory database or a temp folder: run the stand-in in the tests.
- A remote service that you own: put a port at the seam. Production gets a network adapter, tests get an in-memory adapter.
- A third-party service: pass it in, and give the tests a fake.

## Design it twice

When the interface is the hard part, do not take the first design.

1. Write the constraints: the callers, the data, the dependencies and the error cases.
2. Start 3 subagents in parallel with the same constraints and one different goal each: the smallest interface (1 to 3 entry points), the simplest call for the most common caller, and the most flexible interface. If you cannot start subagents, write the 3 designs yourself, one after the other.
3. Each design gives the interface, one usage example, what it hides, how it handles dependencies, and where it is weak.
4. Compare the designs on depth, on where future changes land, and on where the seam sits. Recommend one, or a mix of two, and say why.

## Further reading

John Ousterhout, *A Philosophy of Software Design* (deep modules, design it twice). Michael Feathers, *Working Effectively with Legacy Code* (seams).
