## Context

The first application cutover (OrderHub) cannot be scheduled until Northwind has signed off on the landing-zone design in writing. The sign-off confirms the networking, identity, and backup configuration we will be cutting over into.

## Rationale

A verbal "looks good" is not enough to commit a maintenance window to the sponsor. If we schedule the cutover and the landing zone changes underneath us, the runbook is invalid and we burn the window.

## Open questions

- Does the backup configuration meet Acme's 30-day retention requirement, or is that the thing still under review on Northwind's side?

## Next step

Hold the vendor to 2026-06-04. If it slips again, escalate to Mark with the contract-backstop date attached.
