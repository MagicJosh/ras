# Spec: Retry failed webhook deliveries

## Goal
A webhook that fails with a timeout or a 5xx is sent again, up to 5 times, with growing delays, and each try is logged.

## Decisions
- Keep retries in the existing jobs table with a `next_try_at` column. Rejected: a new message queue service. Hard to undo: no.
- Back off as 30 s, 2 min, 10 min, 1 h, 6 h. Rejected: a fixed 1 min delay. Hard to undo: no.
- Store each try as a row in `delivery_attempts`. Rejected: a counter on the delivery row. Hard to undo: yes.

## Proposed additions
| Detail | Proposal | Why it matters |
|---|---|---|
| A 4xx response | Do not retry | The receiver rejected the payload; sending it again gives the same answer |
| Manual retry | Out of scope for now | Needs an admin screen |

## Acceptance criteria
1. A delivery that times out is tried again after 30 s: `pytest tests/test_retry.py::test_timeout_retries`.
2. After 5 failed tries the delivery is marked failed and not tried again: `pytest tests/test_retry.py::test_gives_up`.
3. A 4xx response is not retried: `pytest tests/test_retry.py::test_no_retry_on_4xx`.
4. Every try writes one `delivery_attempts` row: `pytest tests/test_attempts.py`.

## Non-goals
- No retry button in the admin screen.
- No change to how webhooks are signed.

## Work packages
- Wave 0: Schema. Add `next_try_at` and the `delivery_attempts` table.
- Wave 1: Retry loop. The worker picks due deliveries and backs off.
- Wave 1: Attempt log. One row per try, with status and duration.
- Wave 2: Review. Fresh review of the diff, then the full test run.

## Blast radius
- `app/webhooks/deliver.py`: sends one delivery, now returns the outcome. Callers: `app/worker.py`, `tests/test_retry.py`.
- `app/models.py`: new column and table. Callers: `app/webhooks/deliver.py`, `app/worker.py`.
- `migrations/0042_retries.sql`: the schema change.

## Assumptions
- The worker already runs every 10 s, so a 30 s delay is honored within 10 s.
- Receivers treat a repeated delivery id as a duplicate.
