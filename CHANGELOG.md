# Changelog

All notable changes to project-assistant are documented here. This project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-06-02

Initial public release.

### Added
- **Cards.** Three operational cards — project, action, meeting — plus a supporting contact card, and five extended cards: issue, risk, decision, milestone, deliverable.
- **Atlas.** Identity, a strategic spirit (collaborative, non-manipulative; informed by Robert Greene's reading of human nature, inverted toward power-*with*), and operating rules.
- **Method.** A deliberately light card method ("capture and currency"), an onboarding interview, and the Cynefin sense-making reference (with an optional `cynefin_domain` on decision-cards).
- **Schemas.** JSON Schema (Draft 2020-12) for every card type, validated end-to-end.
- **Tooling (PowerShell 7+, cross-platform).** `rebuild-index` (indexes + auto-flags), `generate-dashboard` (self-contained HTML with action-card columns and a Project register for the extended cards), `validate-cards` (ajv-cli when available, dependency-free light checks otherwise).
- **Sample.** A worked Acme Logistics workspace with a pre-generated dashboard and one of every card type.
- **Interop.** A shared data model with the Miles meeting-reflection companion (the meeting-card is shared; Atlas owns the factual layer, Miles the reflection layer).
