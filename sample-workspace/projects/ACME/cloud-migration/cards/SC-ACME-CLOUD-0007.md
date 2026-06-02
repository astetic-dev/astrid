## Context

The OrderHub rollback took ~5.5h in the dry-run (issue [[ISS-ACME-CLOUD-0002]]) against a committed 4-hour maintenance window. Until the rollback fits the window, the cutover cannot be scheduled — so this blocks milestone "OrderHub live on Northwind".

## Rationale

A rollback you can't complete inside the window is not a rollback you can rely on. Trimming it is cheaper than negotiating a longer window with the business.

## Open questions

- Is the time in data copy (parallelize?) or in verification steps (can some run post-cutover)?

## Next step

Profile the rollback phases, cut or parallelize the longest, re-rehearse, and fold the result back into the runbook deliverable.
