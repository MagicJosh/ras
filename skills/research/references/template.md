# Research result

The form of a research result, for the `research` skill and the `researcher` agent. Keep the headings and their order. Leave out a section that does not fit the question: Recommendation is for a choice, Hypotheses for an error, Changes for a version question. Evidence, Gaps and Confirm are always there.

```markdown
# Research: <the question in one line>

Date: <date>. Checked against: <package and installed version, and how: read, searched or executed>.

## Answer
One or two sentences that commit to an answer.

## Recommendation
Chosen: <option>, because <reason>.
- Rejected: <option>. Bad, because <one reason>.

## Hypotheses
| Cause | Evidence for | Evidence against | Prediction to test |
|---|---|---|---|

## Changes
| Version | Change | Affected symbol | Used in this repo |
|---|---|---|---|

## Evidence
| # | Claim | Source | Excerpt | Status |
|---|---|---|---|---|
| 1 | one checkable statement | link, with the page's date when it shows one | the words on the page | verified |

## Conflicts
Sources that disagree, both shown with their dates. "None found" when there are none.

## Gaps
What was not found, what could not be opened (with the host), and what was not checked.

## Confirm
One command or check that the reader can run to confirm the answer.
```

## Status values

The status says what was done, not how sure anyone feels.

| Status | Means |
|---|---|
| `verified` | The page was opened and the claim is on it, or the claim was checked in the installed code |
| `search summary` | Seen only in a search result |
| `inference` | Reasoning from the cited findings, not stated by a source |
| `not verified` | The source could not be opened, or it did not support the claim |

## Rules for the table

- One claim per row, at most 12 rows. Keep the claims the answer rests on.
- "Used in this repo" holds a file path, or "not used".
- An excerpt is word for word. When a tool returned a summary of the page and not its text, write "(tool summary)" after the excerpt.
