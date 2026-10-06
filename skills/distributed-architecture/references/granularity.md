# Granularity checklist: split or join

Use this file to test one proposed service boundary. Answer each question with evidence from your system. Write "unknown" when you have none. Then measure before you decide.

## Questions that favor a split

### Cohesion

- Does the candidate part do several unrelated jobs?
- Can you describe it in one sentence without the word "and"?
- Do different teams or experts care about its different parts?

### Change rate

- Which files change most often? Use version history, not opinion.
- Do small changes in one area force a full release and full test run of everything?
- Would the fast-changing part ship more often if it stood alone?

### Load and scale

- Does one part need ten times more capacity than another?
- Does the load peak at different times?
- Does the heavy part waste resources by scaling together with the light parts?

### Fault tolerance

- If this part crashes, what else stops?
- Must some features keep working while others are down?
- Does a memory leak or slow call in one part hurt the rest?

### Security

- Does one part handle regulated or very sensitive data?
- Would a smaller attack surface or separate access rules help?
- Would auditors prefer a clear boundary?

### Team and extension

- Do teams wait on each other to merge and release?
- Will new features of one kind arrive soon? Is the new work unrelated to the rest?

## Questions that favor a join

### Transactions

- Must these changes succeed or fail as one unit?
- What does the business lose if they show a half-done state for a minute? For an hour?
- Would a saga here be harder than the monolith problem you want to fix?

### Workflow

- Does one part call the other on nearly every request?
- Does a call from A to B always need a reply from B before A can go on?
- Would a failed call leave the caller unable to do useful work?

### Shared code

- Do both parts depend on the same domain classes or rules?
- Would you need a shared library that changes with each release?
- Would a shared service just move the coupling to runtime?

### Data relationships

- Do the parts share tables, foreign keys, or joins?
- Would cutting the data link force copies in several places?
- Who would own each shared table?

## Reading the results

1. List the answers that favor a split. Mark each as measured, observed, or guessed.
2. List the answers that favor a join in the same way.
3. Give more weight to measured facts and hard business rules than to taste.
4. A hard transaction rule usually outweighs many soft split reasons.
5. If the forces are about equal, keep the code together and add an internal module boundary. Revisit when new data arrives.

## Size warnings

- A service named "misc", "common", or "other" is a leftover. Re-check cohesion on both sides.
- A service with one endpoint and one table may be too small if it always changes with its caller.
- A service with many unrelated endpoints and many tables may be too big if teams collide in it.
- Services that must release in lock step are one unit in practice. Merge them or fix the contract.
- No size number works for every system. Use lines of code, endpoint counts, or class counts only as signals to look closer.

## Before you extract

- Make the code boundary clean inside the monolith first. Use modules and enforce dependency rules.
- Map the data for the part. See `data.md`.
- List the new calls that replace in-process calls.
- Plan the saga for each business operation that now crosses the line.
- Pick a rollback path for the first release of the new service.
- Add a check that fails the build if a forbidden dependency returns.
