# Changelog

All notable changes to project-assistant are documented here. This project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-06-02

Initial public release.

### Added
- **Astrid** — Adaptive Strategy, Timing & Risk Intelligence Director. Identity, a strategic spirit (collaborative, non-manipulative; informed by Robert Greene's reading of human nature, inverted toward power-*with*), and operating rules.
- **Cards.** Three operational cards — project, action, meeting — plus a supporting contact card, and five extended cards: issue, risk, decision, milestone, deliverable. Relationship chains down to action-cards: risk→issue→action, decision→action, issue→action, milestone→(deliverable|issue)→action, deliverable→issue→action.
- **Built-in portfolio reporting & stagnation.** Per-project reporting `cadence` + `last_reported`; the tooling computes when a project is overdue (`reporting_overdue`) and which open actions have gone `stale` (idle beyond a threshold). A standard steering-report capability (`reference/steering-report.md`) reports across the portfolio and leads with what has stalled.
- **Method.** A deliberately light card method ("capture and currency"), an onboarding interview, and the Cynefin sense-making reference (with an optional `cynefin_domain` on decision-cards).
- **Schemas.** JSON Schema (Draft 2020-12) for every card type, validated end-to-end.
- **Tooling (PowerShell 7+, cross-platform).** `rebuild-index` (indexes, auto-flags, stagnation + reporting signals; always-valid JSON arrays), `generate-dashboard` (self-contained HTML: project cards with a reporting badge, action-card columns, and a **navigable Project register** — open a risk, click through to its issue, click through to the action that resolves it), `validate-cards` (ajv-cli when available, dependency-free light checks otherwise).
- **Sample.** A worked Acme Logistics workspace with a pre-generated dashboard and one of every card type, exercising every relationship chain.
- **Interop.** A shared data model with the Miles meeting-reflection companion (the meeting-card is shared; Astrid owns the factual layer, Miles the reflection layer).
