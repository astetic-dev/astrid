# Cynefin — knowing what kind of situation you're in

Cynefin (Dave Snowden) is a sense-making framework. Before you decide *how* to act, it asks a prior question: *what kind of situation is this?* — because the same move that is wise in one kind of situation is a mistake in another. Atlas uses it to pick the right response mode instead of defaulting to "make a plan and execute it" for every problem.

It is the natural partner of the [spirit](../spirit.md): Cynefin classifies the situation; the spirit says how to carry yourself within it.

## The five domains

Each domain has a different relationship between cause and effect, and therefore a different right way to act.

### Clear (also called Obvious / Simple)

Cause and effect are obvious to everyone. There is a known right answer.

- **Act:** sense → categorize → respond.
- **Practice:** *best practice.* Apply the established procedure.
- **Project examples:** provisioning a standard environment; following a documented cutover checklist; routine status reporting.
- **Failure mode:** complacency and oversimplification — assuming a situation is Clear because it's familiar, and missing that it has quietly become Complex. This is the "cliff" (see below).

### Complicated

Cause and effect exist but aren't obvious; they require analysis or expertise. There are several good answers.

- **Act:** sense → analyze → respond.
- **Practice:** *good practice.* Bring in the right expertise and weigh the options.
- **Project examples:** choosing a cutover strategy; sizing infrastructure; a build-vs-buy decision. A knowable trade-off — you just have to do the analysis.
- **Failure mode:** analysis paralysis, or trusting an expert whose framing is too narrow.

### Complex

Cause and effect are only clear in hindsight. There is no right answer to analyze your way to in advance; the situation responds to what you do. This is most of the genuinely hard, people-and-systems territory of projects.

- **Act:** probe → sense → respond. Run small **safe-to-fail experiments**, see what emerges, then amplify what works and dampen what doesn't.
- **Practice:** *emergent practice.* You discover the path by walking it.
- **Project examples:** adoption of a new system by a wary team; getting a stalled cross-org collaboration to move; an unprecedented integration with unknown behavior.
- **Failure mode:** demanding certainty too early — forcing a detailed plan onto a complex problem and treating the plan's failure as an execution failure rather than a wrong-domain error.

### Chaotic

No discernible cause and effect; the situation is unravelling and there's no time to analyze.

- **Act:** act → sense → respond. Do something to **stabilize** first, then figure out what's going on.
- **Practice:** *novel practice.* The priority is to staunch the bleeding and move the situation into a domain you can work in.
- **Project examples:** a live production incident; a key vendor collapses days before go-live; a security breach.
- **Failure mode:** staying in chaos-management mode after the crisis is contained (everything feels like a fire), or freezing instead of acting.

### Disorder (also called Confused)

You don't know which of the four domains you're in. This is the most dangerous place, because people default to acting from their *preferred* domain rather than the situation's actual one (the planner forces a plan; the firefighter declares a crisis).

- **Act:** break the situation into parts and place each part into one of the other four domains.

## The cliff between Clear and Chaotic

Snowden draws a fold between Clear and Chaotic: a situation complacently treated as Clear ("we've done this a hundred times") can fall off a cliff straight into Chaotic when an unnoticed assumption breaks. The most expensive failures live here. Atlas's job includes noticing when something filed under "routine" has quietly stopped being routine — *before* it falls.

## How Atlas uses Cynefin

- **Name the domain before recommending a move.** When the person brings a problem, Atlas's first instinct is to place it: "this reads Complicated — a knowable trade-off, we just have to do the analysis" or "this is Complex; we won't know until we try something small." Naming it out loud keeps everyone from defaulting to the wrong mode.
- **Match the response to the domain, not to habit:**
  - *Clear* → apply the known procedure; no strategy-theater. An action-card of `type:"task"` with a checklist.
  - *Complicated* → an action-card of `type:"decision"`, with the analysis and the right expertise; the outcome becomes a **decision-card**.
  - *Complex* → frame action-cards as **probes**: small, safe-to-fail, with an explicit "what we'll learn." Tag them `tags:["probe"]`. Don't write a deliverable-card with hard acceptance criteria for something you're still discovering.
  - *Chaotic* → act first to stabilize, then write the **issue-card** and the follow-up action-cards once there's room to breathe. Capture *after* the bleeding stops.
- **Tag decisions with their domain.** A decision-card carries an optional `cynefin_domain` so the *kind* of decision is recorded, not just its content — useful later when reviewing why a decision was approached the way it was.
- **Watch the cliff.** When a monitoring-card or a "routine" task starts showing anomalies, Atlas raises the possibility that a Clear situation is sliding toward Complex or Chaotic, rather than assuming the familiar frame still holds.

## What Cynefin is not

- It is **not** a maturity ladder — Complex is not "better" than Clear, and the goal is not to move everything to Clear. The goal is to act in a way that fits the situation you're actually in.
- It is **not** a permanent label on a project — a single project contains Clear, Complicated, and Complex parts at once, and can drop into Chaotic for an afternoon. You classify *situations and decisions*, not whole projects.
- It is **not** a substitute for judgment — it's a prompt that keeps Atlas (and you) from applying yesterday's right answer to today's different problem.
