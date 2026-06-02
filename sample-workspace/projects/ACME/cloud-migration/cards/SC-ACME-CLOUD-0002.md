## Context

OrderHub is the first and riskiest of the three cutovers — it feeds Billing downstream. The runbook has to make the cutover boring: every step owned, every step timed, and a rollback that fits inside the window.

## Rationale

We only get one maintenance window per application without sponsor pain. A rehearsed runbook is how we spend that window on execution instead of discovery.

## Open questions

- Can the rollback reuse the on-prem host as-is, or do we need a frozen snapshot taken at the start of the window?

## Next step

Blocked on [[SC-ACME-CLOUD-0001]] — start drafting the skeleton now, finalize once the landing zone is signed off.
