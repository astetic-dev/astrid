# Steering report — a standard Astrid capability

This is not an optional companion. Producing a steering/stakeholder report across the whole portfolio — and noticing stagnation before a stakeholder does — is one of Astrid's core jobs. This page is how Astrid does it.

## When to run it

- The user asks: *"give me a steering report"*, *"what should I report this week"*, *"status across everything"*.
- A project is **overdue for reporting** (the dashboard and `rebuild-index` flag `reporting_overdue`). Astrid surfaces this unprompted at the start of a session: *"ACME-CLOUD is past its monthly report — want me to draft it?"*

## Inputs (read these first)

All from the generated `_index/` (run `rebuild-index.ps1` first so the signals are current):

- `projects.json` — per project: `status`, `health_level`/`health_since`, `report_cadence`, `last_reported`, `report_next_due`, `reporting_overdue`, `days_since_reported`.
- `cards-open.json` — open action-cards with `late`, `urgent`, and **`stale`/`days_idle`** (the stagnation signal).
- `risks.json`, `decisions.json`, `milestones.json`, `deliverables.json`, `issues.json` — the register, with status and key fields.
- Each card's `latest_update` and `.log.jsonl` — for "what changed since the last report."

## Scope

Default: **all projects**, led by the ones that are `reporting_overdue`. If the user names a project, scope to it. Respect each project's `reporting.cadence` — a quarterly project doesn't belong in a weekly sweep unless it's due.

## What "since last report" means

Anchor on each project's `reporting.last_reported`. "What changed" = `latest_update`s and log entries dated **after** that date, plus any status/health change. If `last_reported` is null, report from project start and say so.

## Output shape

Lead with a **portfolio summary**, then one section per project. Keep it concise and paste-ready (no hard wrapping). Use the project's RAG (health) up front.

### Portfolio summary (3-6 lines)
- How many projects green / yellow / red, and which moved.
- Anything overdue for reporting.
- The one or two things steering actually needs to decide or know.

### Per project
- **Header:** name · status · health (RAG) · reporting status (last reported / due).
- **Since last report:** what changed — decisions made, milestones hit/slipped, risks that moved. Pulled from `latest_update`s, not invented.
- **Milestones:** upcoming, `at-risk`, or `missed` (with target vs baseline if slipped).
- **Top risks:** `high`/red risks and any `realized` risk (now an issue).
- **Open decisions:** decision-cards in `proposed` status awaiting a call — especially ones going to *this* steering.
- **Stagnation — name it plainly:** action-cards flagged `stale` (idle > threshold) and `WAIT`/`BLOCKED` cards that have been waiting too long. This is the part most reports omit and the part steering most needs. For each: the card, how long it's been idle, and what it's waiting on.
- **Asks / escalations:** what you need from steering. Be specific (a decision, an unblock, a resource).

## Discipline

- **Stagnation is the headline, not a footnote.** A report that only lists progress and hides the three actions that haven't moved in three weeks is the kind of report that lets a project drift to red quietly. Astrid leads each project section's risk view with what has *stalled*.
- **Don't invent progress.** If `latest_update` is stale or missing, say "no recorded change since last report" — that itself is a signal.
- **Stay factual.** This is a documentation/communication task, not coaching. (Reflection on how a meeting was run is Miles' job, not this.)
- **Honour the spirit.** Frame asks in terms of what steering cares about; time the escalation to be heard; never characterize a person — describe the behaviour and the need (see `spirit.md`).

## Close the loop

After producing a report, offer to record it: set each reported project's `reporting.last_reported` to today's date (the user supplies "today"), then re-run `rebuild-index.ps1` so `report_next_due` and `reporting_overdue` recompute. A report that doesn't update `last_reported` leaves the project looking permanently overdue.

## Optional: a recurring sweep

This capability pairs naturally with a scheduled "Monday portfolio sweep" — same inputs, run on a cadence, surfacing `reporting_overdue` projects and newly-`stale` actions. That automation is left to the host (a cron/scheduled agent); the report logic is here.
