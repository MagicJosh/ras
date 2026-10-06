# Decisions and risk

## ADR guidance

An ADR is a short record of one design decision. It keeps the reason alive after the people move on.

Template:

```
Title:
Status: proposed | accepted | superseded by <id>
Context: forces, limits, and the top characteristics
Decision: "We will ..." in active voice
Consequences: gains, costs, new risks
Alternatives: options rejected, with the reason
Fitness functions: checks that guard the decision
```

Rules for good ADRs:

- Write one decision per record.
- Write the context before the decision. A reader must see the forces first.
- State the cost in the consequences. A record with only gains is a sales note.
- Never edit an accepted record to change its meaning. Write a new record that supersedes it.
- Store ADRs in the repository next to the code. Number them in order.
- Ask the owner of each affected area to review before you mark the record accepted.
- Link the record to the checks that guard it.

Decisions that deserve an ADR: a style choice, a split or merge of services, a shared data store, a new messaging system, a major technology pick, a change to a fitness function threshold.

## Risk grid

Rate likelihood and impact from 1 to 3. Multiply them.

| | Impact 1 | Impact 2 | Impact 3 |
|---|---|---|---|
| **Likelihood 3** | 3 medium | 6 high | 9 high |
| **Likelihood 2** | 2 low | 4 medium | 6 high |
| **Likelihood 1** | 1 low | 2 low | 3 medium |

Reading the score:
- 1 to 2: low. Watch it.
- 3 to 4: medium. Plan a mitigation.
- 6 to 9: high. Fix it before launch or accept it in writing.

Rate a risk as high likelihood when the technology is new to the team or has no proof at your scale.

## Group risk session

Use this when several people share the design.

1. Pick the areas of the design to review. One diagram per area works well.
2. List the risks for each area. Include data loss, outage, security gaps, and missing skills.
3. Each person rates each risk alone and in silence. Use the grid above.
4. Show all ratings at once. Do not let early voices steer the rest.
5. Discuss every risk where raters differ by two points or more. Someone often knows a fact the others lack.
6. Agree on a final score for each risk.
7. Write a mitigation for each high risk. A mitigation can change the design, add a check, add a test, or add training.
8. Rate again after the mitigation. If the score stays high, escalate.

## Common mitigations

- Single point of failure: add a replica or a fallback path.
- Unproven technology: build a small prototype that tests the exact use case.
- Team skill gap: pair people, train, or hire.
- Hidden coupling: add a dependency check to the pipeline.
- Data loss: add backups and a restore drill.
- Vendor lock-in: wrap the vendor behind your own interface.
