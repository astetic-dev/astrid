## Context

The data-center contract renews automatically for another 12 months on 2026-12-31 unless the on-prem hosts are decommissioned and termination is confirmed before then. This is the hard outer deadline the whole project hangs from.

## Rationale

A monitoring-card has no single "done" moment until the very end — its job is to keep a slow-moving deadline visible so it never becomes a surprise. It stays in DOING and gets revisited, not closed and reopened.

## Next step

Recompute the latest-safe cutover dates whenever the schedule moves. If the last cutover + 30-day soak no longer clears 2026-12-31, raise the alarm immediately.
