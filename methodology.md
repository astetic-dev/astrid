# The method — light by design

This system carries a method, but a deliberately thin one. The goal is not to impose a project framework on you; it's to keep the truth of your work in one place at almost no maintenance cost. Adopt the parts that earn their keep and ignore the rest.

## The one idea

**Capture and currency.** Two disciplines, and only two:

1. **Capture** — every commitment, decision, blocker, and thing-to-watch becomes a card. If it lives only in your head or your inbox, it isn't tracked.
2. **Currency** — the cards stay true, especially the one-line "what just changed." A small set of true cards beats a large set of stale ones every time.

Everything else in this document is in service of those two. If a rule ever fights them, the rule loses.

## Three cards, three questions

The system has three card types because projects have three different kinds of memory, each with its own lifecycle:

| Card | Answers | Lifecycle |
|---|---|---|
| **project-card** | "What is this for, and where does it stand?" | One per project. Written once, updated when status/scope/health meaningfully change. |
| **action-card** | "What needs doing, by whom, by when — and what's it waiting on?" | Many per project. The operational heartbeat; created and closed constantly. |
| **meeting-card** | "What happened in this meeting, and what work did it produce?" | One per meeting. Factual record; optionally the seed for reflection (via the Miles companion). |

A fourth, supporting artifact — the **contact-card** — exists so a person's details live in exactly one place and every card just references them by id.

See [reference/data-model.md](reference/data-model.md) for how they link into one graph.

## The action-card states

A card moves through a small set of hand-set states. Keep it this small; resist the urge to add more.

```
PLAN ─▶ TODO ─▶ DOING ─▶ DONE
                  │
        WAIT ◀────┤        (waiting on someone external)
     BLOCKED ◀────┤        (can't start; an external blocker is in the way)
                  └─▶ CANCELLED  (deliberately stopped, no delivery)
```

`late` and `urgent` are **not** states — they're flags computed automatically (a card is `late` if its deadline has passed and it isn't done; `urgent` if it's high-priority, or medium-priority and late). You set the state; the system sets the flags. This keeps "is it overdue" honest and out of your hands.

## Four kinds of work

Action-cards carry a `type`, because "things to do" aren't all the same shape:

- **task** — there's an output to produce. Most cards.
- **decision** — the deliverable is a *choice made and recorded*, with a decision-maker named. Don't let decisions hide as tasks; they have a different done-condition (the decision is logged, not the work performed).
- **monitoring** — something to keep an eye on with no single done-moment: a slow deadline, a risk, a dependency. It sits in DOING and gets revisited, not closed and reopened.
- **blocker** — it's holding other work up. Blockers get surfaced first, always, because their cost is multiplied across everything downstream.

## Sizing projects (optional)

If you want a sizing convention, the default is three buckets, recorded in the project-card's `classification` field:

- **S** — a few action-cards, one stakeholder, days-to-weeks. Often no real risks. The project-card can stay thin (purpose, scope, status).
- **M** — multiple stakeholders, a timeline that matters, real risks worth listing. The full project-card earns its keep here.
- **L** — large enough that this system is a *companion* to a heavier tracker (Jira/Linear/a formal PID), not the system of record. Use the cards as your personal operational layer and reference the official artifacts from the project-card.

This is a hint, not a gate. If you have your own sizing or staging convention, put it in `classification` and use that instead.

## Match your approach to the situation (Cynefin)

Not every problem should be met with "make a plan and execute it." Before choosing how to act, classify the kind of situation you're in — the Cynefin framework (full treatment in [reference/cynefin.md](reference/cynefin.md)):

| Domain | Cause & effect | Act by | Card move |
|---|---|---|---|
| **Clear** | obvious; known right answer | apply best practice | a `task` with a checklist |
| **Complicated** | knowable by analysis | analyze with expertise | a `decision` action-card → a decision-card |
| **Complex** | only clear in hindsight | run safe-to-fail probes | action-cards framed as probes (`tags:["probe"]`) — not hard deliverables |
| **Chaotic** | no time to analyze | stabilize first, then sense | act, then capture the issue-card + follow-ups |
| **Disorder** | you don't know which | break it into parts, classify each | — |

The recurring mistake is applying a Clear-domain answer ("we've done this before") to what has quietly become a Complex or Chaotic situation. Naming the domain out loud is the cheap insurance against it. Cynefin classifies *situations and decisions*, not whole projects — one project holds several domains at once.

## More cards, when you need them

The three operational cards (project / action / meeting) carry most projects. Five more exist for when a project earns the structure — they all live at the project level and link their work down into action-cards. Reach for them deliberately, not by default:

- **issue-card** — when you need to track bugs, defects, incidents, or open questions, and you have no external tracker (or want a personal record). An issue is something *observed*; the work to fix it lives as action-cards it points to (`action_cards[]`). Severity (how broken) and priority (how urgent for the business) are tracked separately — a high-severity crash on an unused screen can be low priority, and vice versa.
- **risk-card** — when a risk needs real management: an assessment (probability × impact), a response strategy, an owner, and a review date. For small projects, **don't** — the project-card's inline `risks[]` (max 5) is the lightweight option, and the right default. Promote a risk to its own card only when it needs mitigation work and periodic review. A realized risk becomes an issue-card.
- **decision-card** — the durable record of a decision once made (an ADR: context → decision → consequences, plus the options you ruled out). Distinct from an action-card of `type:"decision"`, which is a decision that still needs *driving*. The flow: drive the pending decision as an action-card; when it's made, write the decision-card and point its `resolves_action_card` back at the action-card, which then goes DONE. The pending decision and the made decision are two different states of the same thing, in two different cards.
- **milestone-card** — a moment in time (binary: reached or not), often a gate, a payment trigger, or a phase boundary. Baseline its date so schedule slip stays visible. Deliverables and action-cards hang under it.
- **deliverable-card** — a thing you must produce and someone must accept: a format, an owner, a recipient, acceptance criteria, a sign-off. Rolls up to a milestone. The acceptance criteria are required for the same reason a project needs success criteria — so "accepted" is a fact, not an opinion.

The discipline is the same as everywhere else: a card exists to keep something true and visible at low cost. If maintaining one of these stops paying for itself, drop back to the three core cards.

## What "done" means

A card is done when it would pass its own `acceptance_criteria`. If you didn't write criteria, the test is simpler and stricter: *would you be comfortable if the customer saw this marked done?* When in doubt, it's still DOING. A DONE card that isn't is the single fastest way to stop trusting your own dashboard — and once you stop trusting it, you stop using it.

## What this method deliberately does not do

- **No estimation/velocity/burndown.** This isn't agile-in-a-box. If you need those, your team tracker has them.
- **No mandatory grooming ritual.** The system stays current because you touch cards as you work, not because of a weekly ceremony.
- **No approval workflows or sign-off states.** A card is a personal commitment, not a governance object. If something needs formal sign-off, that lives in your official tracker and the card references it.
- **No required fields beyond the few that keep a card honest.** Title, status, type, priority, owner, a deadline-text, and a true `latest_update` when things move. Everything else is there when you need it and absent when you don't.
