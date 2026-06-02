# Data model — four cards, one graph

The system is four connected JSON artifacts. Together they form a small graph that grows with your work. project-assistant operates all four; the meeting-coach companion (Miles) reads the same project-card, meeting-card, and contact-card.

```
┌───────────────────────────┐
│       project-card        │  ← one per project (project.json)
│       "the anchor"        │    purpose, scope, status, health,
│                           │    stakeholders[], timeline, risks,
│                           │    + optional ops: budget, environments,
│                           │      references, action_cards_glob
└─────────┬──────────┬──────┘
          │          │
 stakeholders[]      │ action_cards_glob / meetings_glob
 .contact_id         │
          │          ├───────────────────────────┐
          ▼          ▼                            ▼
          │   ┌───────────────────────┐   ┌───────────────────────┐
          │   │      action-card      │   │     meeting-card       │
          │   │  "the work"           │   │  "what happened"       │
          │   │  {id}.json            │   │  MTG-...json           │
          │   │  + {id}.md (body)     │   │  decisions[],          │
          │   │  + {id}.log.jsonl     │   │  action_cards_created[]│
          │   │  status, type,        │   │  attendees[],          │
          │   │  priority, deadline,  │   │  (+ Miles' analysis)   │
          │   │  latest_update,       │   └───────────┬───────────┘
          │   │  depends_on/blocks    │               │
          │   └───────────────────────┘   attendees[].contact_id
          │                                           │
          ▼                                           ▼
        ┌─────────────────────────────────────────────────┐
        │                 contact-card                     │  ← one per person
        │              "the people"                        │    (centralized in _contacts/)
        │   name, organization, role, active,              │
        │   involved_in[]                                  │
        └─────────────────────────────────────────────────┘
```

## Relations and cardinality

| Relation | Cardinality | Implementation |
|---|---|---|
| project ↔ action | **1-to-many** | Each action-card's `project.{customer_code,project_code}` matches the project-card id. A project accumulates many action-cards. |
| project ↔ meeting | **1-to-many** | Each meeting-card has one `project_id`. |
| project ↔ contact | **many-to-many** | project-card `stakeholders[].contact_id`; contact-card `involved_in[]`. |
| meeting ↔ contact | **many-to-many** | meeting-card `attendees[].contact_id`. |
| meeting → action | **1-to-many** | meeting-card `action_cards_created[]` lists the cards a meeting produced. |
| action ↔ action | **graph** | `depends_on`, `blocks`, `relates_to`, `parent_id`, `split_from`/`split_into`, `supersedes`. |

## The three-file action-card

An action-card is not one file — it's three, sharing a base name:

```
cards/
  SC-ACME-CLOUD-0001.json        ← structured data (the schema)
  SC-ACME-CLOUD-0001.md          ← narrative body: ## Context / ## Rationale / ## Open questions / ## Next step
  SC-ACME-CLOUD-0001.log.jsonl   ← append-only activity log, one JSON object per line
```

This split keeps each part doing one job. The JSON holds the queryable state. The `.md` holds the human story that doesn't belong in fields. The `.log.jsonl` holds history, so the card itself only ever shows the *current* truth. For DONE/CANCELLED cards the `.md` and `.log.jsonl` may be dropped.

The **`latest_update`** field on the JSON is the exception that earns its place: a one-line "what just changed," replaced (not appended) on each substantial change, rendered at the top of the dashboard card. It's the answer to "what's the state of this?" without opening anything.

## ID conventions

All ids are uppercase, hyphenated, and pattern-validated by the schemas.

| Artifact | Format | Example |
|---|---|---|
| project-card | `{customer}-{project}` (no user prefix — shared) | `ACME-CLOUD` |
| action-card | `{user}-{customer}-{project}-{NNNN}[suffix]` | `SC-ACME-CLOUD-0007`, `…-0007A` |
| meeting-card | `MTG-{customer}-{project}-{YYYY-MM-DD}-{NN}` | `MTG-ACME-CLOUD-2026-05-26-01` |
| contact-card | `CONTACT-{org}-{name-slug}` | `CONTACT-ACME-mark-thompson` |
| issue-card | `ISS-{customer}-{project}-{NNNN}` | `ISS-ACME-CLOUD-0001` |
| risk-card | `RISK-{customer}-{project}-{NNN}` | `RISK-ACME-CLOUD-001` |
| decision-card | `DEC-{customer}-{project}-{NNN}` | `DEC-ACME-CLOUD-001` |
| milestone-card | `MS-{customer}-{project}-{NNN}` | `MS-ACME-CLOUD-001` |
| deliverable-card | `DLV-{customer}-{project}-{NNN}` | `DLV-ACME-CLOUD-001` |

The `{customer}-{project}` substring is the join key: any card belongs to the project-card whose id it contains (the extended cards carry it as an explicit `project_id`). The action-card's `{user}` prefix scopes work to a person (constant in a solo setup, meaningful in a team); the extended cards are project-level shared artifacts, so like the project-card they carry no user prefix.

**Number-width principle.** High-volume cards — action-cards and issue-cards — use **4 digits** (`NNNN`); the lower-volume register/structural cards (risk, decision, milestone, deliverable) use **3 digits** (`NNN`). Every cross-reference field is patterned to match its target type's id exactly, so a `DLV-…` reference is always 3 digits and an `ISS-…` reference always 4. Keep new references consistent with the target, not with the card you're copying from.

## File layout

```
workspace/
├── _preferences.md                       ← how you work (read by Atlas each session)
├── _contacts/
│   └── CONTACT-ACME-mark-thompson.json
├── projects/
│   └── ACME/cloud-migration/
│       ├── project.json
│       ├── cards/                         ← action-cards (+ .md + .log.jsonl each)
│       │   └── SC-ACME-CLOUD-0001.json …
│       ├── meetings/
│       │   └── MTG-ACME-CLOUD-2026-05-26-01.json
│       ├── risks/        RISK-ACME-CLOUD-001.json …
│       ├── decisions/    DEC-ACME-CLOUD-001.json …
│       ├── issues/       ISS-ACME-CLOUD-0001.json …
│       ├── milestones/   MS-ACME-CLOUD-001.json …
│       └── deliverables/ DLV-ACME-CLOUD-001.json …
└── _index/                               ← generated by rebuild-index.ps1
    ├── cards.json / cards-open.json / cards-done.json
    ├── projects.json / contacts.json
    ├── risks.json / decisions.json / issues.json / milestones.json / deliverables.json
    └── dashboard.html                    ← generated by generate-dashboard.ps1
```

Contact-cards are centralized in `_contacts/` so a person's details — and their departure — change in exactly one place; every card just points at the id.

## The index and dashboard layer

The cards are the source of truth; the `_index/` is a derived, disposable cache that makes them fast to read and pretty to look at.

- **`rebuild-index.ps1`** scans every card, recomputes the `late`/`urgent` auto-flags (writing them back into the cards), and emits the JSON indexes. Run it after any session that changes cards.
- **`generate-dashboard.ps1`** reads the open-cards index, enriches each card with its `.md` body, `.log.jsonl`, and `latest_update`, and writes a single self-contained `dashboard.html` — projects as cards, drill into a project to see Urgent / In progress / Waiting columns, click a card for the full detail. Optional `-IssueBase` / `-WikiBase` parameters turn `issue`/`doc` source refs into deep links.
- **`validate-cards.ps1`** checks every card against its schema (full validation when `ajv-cli` is installed — `npm i -g ajv-cli` — and dependency-free light checks otherwise; having Node alone is not enough).

Because the index is derived, you can delete `_index/` at any time and rebuild it. Nothing of value lives there.

## What the person owns vs. what Atlas writes

| Field | Owner | Notes |
|---|---|---|
| project-card.* | Co-authored at onboarding | Atlas proposes; the person confirms. Updated as the project evolves. |
| action-card core (title, type, owner, deadline) | The person's commitment, Atlas's wording | Atlas shows-then-saves; uses the person's words. |
| action-card.status | The person | Atlas proposes transitions; the person confirms. |
| action-card.latest_update | Atlas | Kept true on every substantial change. |
| action-card.{late,urgent} | The system | Auto-computed. Never hand-set. |
| meeting-card factual layer (decisions, notes, action_cards_created) | Atlas | The record of what happened. |
| meeting-card.{user_intent, analysis, user_reflections} | Miles + the person | The reflection layer — see the meeting-coach companion. |
| extended cards (risk/decision/issue/milestone/deliverable) | Co-authored | Atlas proposes (show-then-save); the person owns assessments, decisions, sign-offs. Atlas keeps statuses and down-links current. |

## The extended card types

Beyond the four core cards, five more sit at the project level for teams/projects that need them. They are all shared artifacts (no user prefix) and all carry an explicit `project_id`. Adopt them when a project warrants the structure; ignore them entirely on small work.

| Card | Answers | Grounded in | Lives in |
|---|---|---|---|
| **issue-card** | "What's broken / unclear / asked — and what work does it need?" | bug/issue-tracker practice (severity = technical impact, separate from priority = business urgency) | `issues/` |
| **risk-card** | "What might go wrong, how bad, and what are we doing about it?" | PMI Practice Standard for Project Risk Management / ISO 31000 | `risks/` |
| **decision-card** | "What did we decide, why, and what did we rule out?" | Architecture Decision Records (Nygard core + MADR supplements) | `decisions/` |
| **milestone-card** | "Did we reach this moment, on time vs the baseline?" | milestone = a moment, binary, gating, baselined | `milestones/` |
| **deliverable-card** | "What must we produce, who accepts it, against what criteria?" | deliverable = a thing, with acceptance criteria + sign-off | `deliverables/` |

### How they connect to the work

The defining edge is that **work flows down into action-cards**. Each of these cards points at the action-cards that carry out its work:

- `issue-card.action_cards[]` — the work to investigate/fix/answer the issue. *(Log the issue here; drive the fix as action-cards.)*
- `risk-card.mitigation_action_cards[]` — the response that works the risk down.
- `decision-card.action_cards[]` — the work the decision sets in motion; `decision-card.resolves_action_card` points back at the `type:"decision"` action-card it closes out.
- `milestone-card.action_cards[]` + `milestone-card.deliverables[]` — what must complete for the moment to be reached.
- `deliverable-card.action_cards[]` + `deliverable-card.milestone_id` — what produces it and which moment it rolls up to.

### Down-links are authoritative; reverse edges are derived

These references are **one-directional by design**: the register card holds the authoritative list of action-cards, and an action-card points back only loosely via `sources[]` (e.g. `{type:"issue", ref:"ISS-ACME-CLOUD-0001"}`, or `type:"risk"`/`"decision"`/`"milestone"`/`"deliverable"`). There is deliberately no `issue_id`/`risk_id`/… field on the action-card — keeping the link in one place avoids two records that can disagree. To find "which issue spawned this action," the indexer derives the reverse edge by scanning the register cards; you do not maintain it by hand. The one fully bidirectional pair is milestone ↔ deliverable (`deliverables[]` ↔ `milestone_id`), because both directions are routinely useful.

**Authoring rule for an LLM:** when you link an action-card into an issue/risk/decision/milestone/deliverable, edit the register card's down-link array (authoritative) and, optionally, add a matching `sources[]` entry on the action-card for readability. Do not invent a back-reference field.

### action-card `type:"decision"` vs the decision-card

These are not duplicates. An **action-card of `type:"decision"`** is a decision that still needs *driving* — it has a deadline and an owner, and it sits in your open work until the call is made. A **decision-card** is the *recorded outcome* (an ADR): context, the decision, consequences, options ruled out. When the decision is made, you create the decision-card and set its `resolves_action_card` to the action-card, then move that action-card to DONE. The pending decision lives as an action-card; the made decision lives as a decision-card.

### Terminal vs open status, per card type

"Is this card still live?" is answered differently per type. Tooling (and Atlas) treat these statuses as **terminal** (everything else is open/active):

| Card | Terminal statuses |
|---|---|
| action-card | `DONE`, `CANCELLED` |
| issue-card | `closed` (and `resolved` is awaiting-verification, *not* yet terminal) |
| risk-card | `closed`, `realized` (a realized risk should become an issue-card via `realized_as_issue`) |
| decision-card | `superseded`, `deprecated`, `rejected` |
| milestone-card | `met`, `missed`, `cancelled` |
| deliverable-card | `accepted`, `rejected` |
| project-card | `done`, `cancelled` |

## Versioning

All schemas carry a `schema_version`. The action-card is at v2 (JSON + sidecar split); project/meeting/contact cards at v1. Changes are additive (new optional fields) where possible; breaking changes increment the version and tooling validates against the declared version.
