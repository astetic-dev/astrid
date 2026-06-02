# Onboarding — the first session

This is the script Astrid runs the first time someone opens the system. It exists because a project assistant is only useful once it knows *your* projects, *your* people, and *how you work*. Five minutes here is what turns Astrid from a generic tool into your operational memory.

Astrid: run this interview conversationally — one topic at a time, not as a form. Listen for things you can card immediately. At the end you will have created a contact-card for the person, a project-card per active project, a handful of seed action-cards, and a short preferences note. Show each artifact before you save it.

---

## Step 1 — Who are you

Ask, lightly:

- **What should I call you, and what's your role?** (PM, consultant, tech lead, freelancer, founder…)
- **Pick a 2–4 letter handle for yourself.** It prefixes your action-card ids, so it should be short and stable — your initials usually. (e.g. `AB`, `SC`, `JL`.) In a solo setup this never changes; in a team it's how cards get attributed.
- **What organization are you in** (or are you independent)?

Create the person's contact-card: `_contacts/CONTACT-{ORG}-{slug}.json` (use `INTERNAL` as the org code if they're independent or it doesn't matter). This is "you" in the system — the internal party on your own projects.

## Step 2 — What are you working on right now

This is the heart of it. Ask:

> **What projects are on your plate right now?** Just name them first — we'll take them one at a time.

Then, for each project, collect enough to write a real project-card. Don't interrogate; pull what they have and flag the rest as gaps to fill later:

- **A name, and a short code.** Customer code + project code → the project id (`ACME-CLOUD`, `NBRG-PORTAL`). For internal/personal projects, invent a customer code (`INT`, your own initials, a product name).
- **Purpose — why does this project exist?** One to three sentences. This field is *hard-required and non-empty* on purpose: it's the thing people forget and the thing that keeps the work honest. If they can't answer it, that's a finding, not a field to skip.
- **What's in scope, and pointedly what's out.** A few bullets each. The out-of-scope list is where scope creep gets caught later.
- **Where is it?** → `status` (initiation / execution / golive / aftercare / done / paused). And a gut-check health: green / yellow / red, and since when.
- **Who are the key people?** Sponsor, customer lead, vendor, your own role. Create an identity-only contact-card for each and reference them in `stakeholders[]`.
- **Any hard dates?** Start, go-live, the deadline that actually scares them.
- **How often do you report on this, and to whom?** Sets the project's reporting cadence (weekly / fortnightly / monthly / quarterly / ad-hoc) and `last_reported`, so Astrid can flag when a steering report is due. Skip for projects you don't report on.
- **The one or two real risks.** Not a risk register — the things that genuinely keep them up.

Once `status` is execution or later, `success_criteria` becomes required — ask "how will you know this project succeeded?" and write measurable answers.

Write each project-card as `projects/<customer>/<project>/project.json`. Show it, save it, move to the next.

## Step 3 — Seed the obvious open work

For each project, ask:

> **What's open on this one right now — what's the next thing, what's blocked, what are you waiting on, what's a decision you owe someone?**

Turn the answers straight into action-cards (`cards/{handle}-{cust}-{proj}-NNNN.json`), picking the type as you go (task / decision / monitoring / blocker). Don't try to be exhaustive — capture the live ones. The system fills in from here as you work. Give each a `deadline.text` at minimum, and an owner or an explicit "owner: ?" gap.

Then run `rebuild-index.ps1` and `generate-dashboard.ps1` so they can *see* it. The first time the dashboard lights up with their real projects is the moment the system becomes theirs.

## Step 4 — How do you work

This calibrates how Astrid behaves for this person. Ask a few, capture the answers in a short `_preferences.md` at the workspace root (free text — Astrid reads it at the start of each session):

- **How often do you want to review?** Daily glance, weekly sweep, only when something's on fire?
- **What does "urgent" mean to you?** The default rule is: priority `high`, or a `medium` card that's gone late. Does that match your instinct, or do you want it tuned?
- **How much should I push?** Some people want me to surface every owner-less blocker and stale `WAIT` card unprompted; others want me to keep quiet unless asked. Where on that line are you?
- **How do you want commitments captured — eagerly or conservatively?** Default is eager: if you say it, I card it unless you wave me off.
- **What method do you already use?** If you have a project-sizing or staging convention (S/M/L, phases, RAG reporting), tell me and I'll record it in the `classification` field. If you don't, [methodology.md](methodology.md) describes the light default this system assumes — adopt as much or as little as you like.

## Step 5 — Your email, and a question worth answering

Here's the question that decides how much this system can do for you:

> **Where does your email live — Outlook, Gmail, an IMAP account, something else? And do you want to wire it in?**

Most commitments are born in email. "Can you send me the runbook by Friday." "We've decided to go with the phased approach." "Still waiting on your sign-off." Every one of those is an action-card or a decision waiting to be captured — and right now you're capturing them by remembering to.

A small **MCP server** for your mailbox closes that gap: it lets Astrid read the relevant mail, and turn a thread into the right card — task, decision, blocker — with the deadline and the owner already filled in, the source linked back to the original message. The inbox stops being a second to-do list you have to mentally reconcile against this one.

So the question, concretely:

1. **Where is your mail?** (This determines which MCP server fits — there are existing community ones for Gmail/IMAP; Outlook can be driven locally on Windows; an Exchange/Graph setup is different again.)
2. **Do you want to build (or wire up) that bridge now, later, or never?** It's entirely optional — the card system works fully without it. But if email is where your work actually arrives, this is the single highest-leverage companion you can add.

Capture their answer in `_preferences.md` (which mailbox, and the decision). If they want it, that becomes the first entry on a "companions to add" list — see the README's *What you can build on this* section, and bring it to whoever's helping you extend the system.

---

## Done

At the end of onboarding the **core** is in place — you, your projects, the live open work, and a dashboard:

```
workspace/
├── _preferences.md              ← how you work + your email answer
├── _contacts/                   ← you + the key people, by id
├── projects/
│   └── <customer>/<project>/
│       ├── project.json         ← one per active project (purpose, scope, status, reporting cadence)
│       └── cards/               ← seeded open action-cards (+ .md body + .log.jsonl each)
└── _index/                      ← generated by the scripts: dashboard.html + json indexes
```

Open `_index/dashboard.html` — that's your portfolio, true as of right now.

### The shape it grows into

You don't build everything up front. As you work, Astrid fills the workspace out — each of these appears only when a project earns it (see [methodology.md](methodology.md) for when to reach for which):

```
projects/<customer>/<project>/
├── project.json
├── cards/          ← action-cards — the heartbeat, created and closed constantly
├── meetings/       ← a meeting-card each time you log a meeting (factual record; seed for Miles)
├── issues/         ← when something breaks, is unclear, or is asked — work hangs off it
├── risks/          ← when a risk needs real management (otherwise it stays inline on project.json)
├── decisions/      ← the recorded outcome of a decision (an ADR)
├── milestones/     ← gates, payment points, phase boundaries
└── deliverables/   ← things to produce and have accepted
```

None of these are mandatory — reach for them only when they pay for themselves. The extended cards surface in the dashboard's **Project register** and link down to action-cards (risk → issue → action, decision → action, milestone → deliverable → action, and so on).

### What you've switched on

- **Capture** — from now on, every commitment you mention becomes a card before it can fall through a crack.
- **Currency** — Astrid keeps each card's one-line `latest_update` true; `rebuild-index` recomputes `late` / `urgent` / `stale` and the per-project reporting-due flag each time.
- **The opener** — every session starts with Astrid reading these cards and telling you what's urgent, late, stalled, or overdue to report — before you ask. When a project hits its reporting cadence, Astrid offers the steering report (see [reference/steering-report.md](reference/steering-report.md)).

That's it — you're set up. Drop into a new chat and tell Astrid what's on your plate today.
