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

Plus a **meeting-card** (`MTG-ACME-CLOUD-2026-05-26-01`) showing the factual layer Atlas writes — decisions and the action-cards a meeting produced — and three **contact-cards** in `_contacts/`.

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
