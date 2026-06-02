# Sample workspace — Acme Logistics cloud migration

A fully worked, fictional workspace so you can see the system populated before you write your own data. Nothing here is real; "Sarah Chen" is the stand-in for *you*, the project manager.

## What's modelled

One project — **ACME-CLOUD**, migrating Acme's three remaining on-prem applications to Northwind Cloud before the data-center contract auto-renews on 2026-12-31. It's in execution, health yellow (a vendor sign-off is late), and it carries the full range of card types:

| Card | Type | Status | Shows off |
|---|---|---|---|
| SC-ACME-CLOUD-0001 | blocker | WAIT | a **late**, gating card with `latest_update`, sources, and `blocks` |
| SC-ACME-CLOUD-0002 | task | PLAN | a card `depends_on` another |
| SC-ACME-CLOUD-0003 | decision | TODO | a decision-card (deliverable = a recorded choice), auto-**urgent** |
| SC-ACME-CLOUD-0004 | monitoring | DOING | a no-end-date watch item (the contract backstop) |
| SC-ACME-CLOUD-0005 | decision | DONE | a closed card — drops out of the open dashboard |
| SC-ACME-CLOUD-0006 | task | DOING | spawned from an issue (`sources` → `ISS-ACME-CLOUD-0001`) — the issue→action loop |

Plus a **meeting-card** (`MTG-ACME-CLOUD-2026-05-26-01`) showing the factual layer Astrid writes, three **contact-cards** in `_contacts/`, a `_preferences.md` (how "Sarah" likes to work), and **one of each extended card** so the register is visible end-to-end:

| Extended card | Id | Shows off |
|---|---|---|
| risk | RISK-ACME-CLOUD-001 | P×I assessment, response, mitigated by action `0001` |
| issue | ISS-ACME-CLOUD-0001 | severity vs priority; spawns action `0006` |
| decision | DEC-ACME-CLOUD-001 | ADR (context/decision/consequences + options), resolves action `0003`, drives `0002`, tagged Cynefin `complicated` |
| milestone | MS-ACME-CLOUD-001 | a gating milestone with a baseline vs target date; rolls up `DLV-…-001` |
| deliverable | DLV-ACME-CLOUD-001 | acceptance criteria + recipient, produced by action `0002` |

The extended cards render in the **Project register** section of the dashboard (open a project to see them under the three action-card columns).

## See it

The `_index/` folder ships pre-generated. Open **`_index/dashboard.html`** in any browser — no server needed.

## Rebuild it yourself

```powershell
pwsh -File ../scripts/rebuild-index.ps1 -Root .
pwsh -File ../scripts/generate-dashboard.ps1 -Root . -Open
```

(Run from this `sample-workspace/` folder. `rebuild-index` recomputes the `late`/`urgent` flags against *today's* date — so which cards show as late will shift over time. That's the system working, not a bug.)

## Validate it

```powershell
pwsh -File ../scripts/validate-cards.ps1 -Root .
```
