# Atlas — your project assistant

**Atlas keeps the truth of your projects in one place.** Every commitment, decision, blocker, and thing-to-watch becomes a small, durable card. Atlas reads those cards before it says anything, surfaces what's late or blocked, and turns the things you mention in passing into tracked work before they fall through a crack. Then it renders the whole portfolio as a dashboard you can open in a browser.

It is built on three operational cards — **project-card**, **action-card**, **meeting-card** — plus a supporting **contact-card**, and a few small scripts that index the cards and build the dashboard. No database, no SaaS, no account. Just JSON files you own, in a folder, that a Claude project reads.

> Atlas is the *operational* half of a card-based methodology. Its companion **Miles** (the meeting reflection coach) is the *reflective* half. They share the same data model — see [Companions](#companions).

---

## Get started in 5 minutes

1. Drop this entire folder into a Claude project (*Project Knowledge → upload folder*).
2. *(Optional but recommended)* Drop the `sample-workspace/` folder in too — it's a worked fictional project (Acme Logistics, a cloud migration) so you can see the system fully populated before writing your own data. Open `sample-workspace/_index/dashboard.html` in a browser right now to see what you're building toward.
3. Open a new chat and say: *"Let's set up my projects."* Atlas runs the [onboarding interview](onboarding.md) — who you are, what you're working on, how you like to work, and where your email lives. Twenty minutes later you have your real portfolio on a dashboard.

Every session after that starts the same way: Atlas reads your cards and tells you where things stand.

## What's in the folder

```
project-assistant/
├── README.md                ← you are here
├── identity.md              ← who Atlas is
├── spirit.md                ← Atlas's strategic character (collaborative, non-manipulative)
├── rules.md                 ← how Atlas operates (the discipline)
├── onboarding.md            ← the first-session interview
├── methodology.md           ← the light project method, explained
├── examples.md              ← three worked sessions, verbatim
├── scripts/
│   ├── rebuild-index.ps1        ← scan cards → JSON indexes + auto-flags
│   ├── generate-dashboard.ps1   ← indexes → self-contained dashboard.html
│   └── validate-cards.ps1       ← check cards against the schema
└── reference/
    ├── data-model.md            ← the cards, one graph
    ├── cynefin.md               ← matching your approach to the kind of situation
    └── schemas/                 ← JSON schemas for every card type
```

Three operational cards carry most work — **project**, **action**, **meeting** (+ the supporting **contact**). Five more are there when a project earns the structure: **issue**, **risk**, **decision**, **milestone**, **deliverable**. They all link their work down into action-cards. See [reference/data-model.md](reference/data-model.md) and [methodology.md](methodology.md) — and reach for them deliberately, not by default.

Separate from the assistant folder, the optional **`sample-workspace/`** ships a fully worked project so you (and anyone reviewing this) can see the system in motion:

```
sample-workspace/
├── _preferences.md              ← how "you" (Sarah Chen) like to work
├── _contacts/                   ← the people, by id
├── projects/ACME/cloud-migration/
│   ├── project.json             ← the project anchor
│   ├── cards/                   ← 6 action-cards (task, decision, monitoring, blocker)
│   ├── meetings/                ← a meeting-card (the factual layer)
│   ├── risks/ decisions/ issues/ milestones/ deliverables/   ← one of each extended card
└── _index/                      ← pre-generated dashboard.html + indexes
```

## The tooling

The cards are plain files you can edit by hand or with Atlas. Three PowerShell scripts turn them into a live view.

**Prerequisite:** PowerShell 7+ (`pwsh`) — free and cross-platform (Windows/macOS/Linux). That's the only requirement. Node.js + `ajv-cli` are optional, used solely for stricter JSON-Schema validation; without them `validate-cards.ps1` runs dependency-free light checks.

```powershell
# from your workspace root:
pwsh -File path/to/scripts/rebuild-index.ps1 -Root .
pwsh -File path/to/scripts/generate-dashboard.ps1 -Root . -Open
```

`rebuild-index.ps1` recomputes the `late`/`urgent` flags and writes the JSON indexes. `generate-dashboard.ps1` builds a single self-contained `dashboard.html` — projects as cards, click into a project for Urgent / In progress / Waiting columns, click a card for its full detail, body, and activity log. Optional `-IssueBase`/`-WikiBase` parameters deep-link your source refs into your tracker or wiki.

## A question worth answering: your email

Most commitments are born in email. *"Send me the runbook by Friday." "We've decided on the phased approach." "Still waiting on your sign-off."* Each is a card waiting to be captured — and today you capture them by remembering to.

So onboarding asks one question that decides how much Atlas can do for you:

> **Where does your email live — Outlook, Gmail, IMAP, something else — and do you want to wire it in?**

A small **MCP server** for your mailbox lets Atlas read the relevant mail and turn a thread into the right card — task, decision, or blocker — with the owner and deadline already filled in and the source linked back. The inbox stops being a second to-do list you mentally reconcile against this one. It's entirely optional; the card system works fully without it. But if email is where your work actually arrives, it's the highest-leverage thing you can add. See [onboarding.md](onboarding.md) §5.

## Companions

Atlas is one building block in a card-based methodology. Companions share the same data model — the same `project.json`, the same contact-cards, the same `meetings/` folder — so they compose without integration work.

- **Miles — the meeting reflection coach.** Atlas records *that* a meeting happened and what work it produced. Miles works on *how you ran it*: anchored strengths, growth moments, and a Socratic mirror, tracked longitudinally. They read the same meeting-card — Atlas owns the factual layer, Miles owns the reflection layer. When you want to get better at the room and not just track it, that's Miles.

## What you can build on this

The cards and the index/dashboard layer are a foundation, not a finished product. Natural extensions: an email→card MCP bridge (above), more card types (a retro-card, a status-report/weeknote snapshot), specialist personas that read the same data (a status-report writer, a stakeholder-comms drafter, a risk reviewer), dashboard views for the extended cards (a risk matrix, a milestone timeline), and recurring automations (a Monday portfolio sweep, a "what went stale" check). The data model is deliberately open so these all plug in.

## License

MIT — see [LICENSE](LICENSE).

## Provenance

Built on the folder-based specialist methodology. Part of a card-based portfolio of project-work companions; designed to interoperate with **Miles**, the meeting reflection coach.
