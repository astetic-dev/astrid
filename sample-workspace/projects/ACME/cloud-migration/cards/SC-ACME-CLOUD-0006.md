## Context

The Billing nightly batch timed out in the Northwind test environment during the first dry-run (see issue [[ISS-ACME-CLOUD-0001]]) — >2h versus ~35 min on-prem on the same dataset. Billing cannot be scheduled for cutover until this is understood.

## Rationale

This is the work that follows from the issue. The issue records *what's wrong*; this card drives *fixing it*. Keeping them separate means the issue can stay open until verified even after the investigation card is done.

## Open questions

- Is it the storage tier (IOPS), a missing index after migration, or a batch-window scheduling difference on Northwind?

## Next step

Profile the batch in the test env; compare query plans against on-prem. Report findings back onto the issue.
