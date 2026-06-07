# intake-scaffold.ps1
# Turns a filled-in intake.json into a working project: scaffolds the structure
# (new-project.ps1), writes a rich project.json, and creates deliverable / risk /
# milestone cards from what the intake provides. Invents nothing — anything the intake
# omits is left out or set to a sensible default. PowerShell 7+.
#
# intake.json shape (see scripts/intake.example.json):
#   {
#     "customer": {"code":"ACME","name":"Acme Logistics"},
#     "folder":"cloud-migration", "project_code":"CLOUD", "title":"...",
#     "status":"initiation", "purpose":"...",
#     "scope_in":["..."], "scope_out":["..."], "success_criteria":["..."],
#     "stakeholders":[{"name":"...","role":"project sponsor","party":"customer"}],
#     "owner_person":"Pat Lee", "start_date":"2026-06-01", "classification":"M",
#     "budget":{"hours":40,"amount":12000,"currency":"EUR","funding_source":"Q-1042"},
#     "quote_file":"documents/quote.pdf",
#     "deliverables":[{"name":"...","acceptance":["..."],"format":"document"}],
#     "risks":[{"title":"...","description":"...","category":"external","response":"mitigate","probability":"medium","impact":"high"}],
#     "milestones":[{"name":"...","target_date":"2026-07-01","gating":true}]
#   }
#
# Usage:  pwsh -File scripts/intake-scaffold.ps1 -IntakeFile path/to/intake.json [-Root .]
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$IntakeFile,
  [string]$Root = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'
$rootAbs = (Resolve-Path $Root).Path
$I = [System.IO.File]::ReadAllText((Resolve-Path $IntakeFile).Path) | ConvertFrom-Json

foreach ($req in 'customer', 'folder', 'project_code', 'title') {
  if (-not $I.$req) { throw "intake.json is missing a required field: $req" }
}
$cc = $I.customer.code
$pc = $I.project_code
$projId = "$cc-$pc"
$today = (Get-Date).ToString('yyyy-MM-dd')
$ownerPerson = if ($I.owner_person) { $I.owner_person } else { $null }
$status = if ($I.status) { $I.status } else { 'initiation' }

# 1. structure
& (Join-Path $PSScriptRoot 'new-project.ps1') -Customer $cc -Folder $I.folder -ProjectCode $pc -Title $I.title -Root $rootAbs | Out-Null
$projDir = Join-Path $rootAbs ("projects/$cc/" + $I.folder)

# 2. rich project.json
$stakeholders = @()
if ($I.stakeholders) { foreach ($s in $I.stakeholders) { $stakeholders += [ordered]@{ name = $s.name; role = $s.role; party = $s.party } } }
elseif ($ownerPerson) { $stakeholders += [ordered]@{ name = $ownerPerson; role = 'project lead'; party = 'internal' } }
else { $stakeholders += [ordered]@{ name = 'TBD'; role = 'project lead'; party = 'internal' } }

$pj = [ordered]@{
  schema_version   = 1
  id               = $projId
  title            = $I.title
  purpose          = $(if ($I.purpose) { $I.purpose } else { 'TODO: why this project exists.' })
  scope_summary    = [ordered]@{ in_scope = @($(if ($I.scope_in) { $I.scope_in } else { @('TODO') })); out_of_scope = @($I.scope_out) }
  status           = $status
  customer         = [ordered]@{ code = $cc; name = $I.customer.name }
  stakeholders     = $stakeholders
}
if ($I.success_criteria) { $pj['success_criteria'] = @($I.success_criteria) }
if ($I.start_date) { $pj['timeline'] = [ordered]@{ start_date = $I.start_date } }
if ($I.budget) { $pj['budget'] = [ordered]@{ hours_estimated = $I.budget.hours; amount = $I.budget.amount; currency = $I.budget.currency; funding_source = $I.budget.funding_source } }
if ($I.classification) { $pj['classification'] = $I.classification }
if ($I.quote_file) { $pj['references'] = [ordered]@{ quote = $I.quote_file } }
$pj['action_cards_glob'] = "cards/*-$cc-$pc-*.json"

($pj | ConvertTo-Json -Depth 8) | Set-Content (Join-Path $projDir 'project.json') -Encoding utf8
Write-Host ("project.json written: " + $projId)

function Pad3($n) { '{0:000}' -f $n }
$levelScore = @{ 'very-low' = 1; 'low' = 2; 'medium' = 3; 'high' = 4; 'very-high' = 5 }

# 3. deliverables
$n = 0
foreach ($d in @($I.deliverables)) {
  if (-not $d.name) { continue }
  $n++; $id = "DLV-$cc-$pc-$(Pad3 $n)"
  $card = [ordered]@{
    schema_version      = 1
    id                  = $id
    project_id          = $projId
    name                = $d.name
    description         = $(if ($d.description) { $d.description } else { $null })
    format              = $(if ($d.format) { $d.format } else { $null })
    owner               = [ordered]@{ party = 'internal'; person = $ownerPerson }
    status              = 'not-started'
    acceptance_criteria = @($d.acceptance)
    action_cards        = @()
  }
  ($card | ConvertTo-Json -Depth 6) | Set-Content (Join-Path $projDir "deliverables/$id.json") -Encoding utf8
}
if ($n) { Write-Host "  deliverables: $n" }

# 4. risks (probability/impact required by schema; default to 'medium' when the intake omits them)
$n = 0
foreach ($r in @($I.risks)) {
  if (-not $r.title) { continue }
  $n++; $id = "RISK-$cc-$pc-$(Pad3 $n)"
  $prob = $(if ($r.probability) { $r.probability } else { 'medium' })
  $imp = $(if ($r.impact) { $r.impact } else { 'medium' })
  $card = [ordered]@{
    schema_version          = 1
    id                      = $id
    project_id              = $projId
    title                   = $r.title
    description             = $(if ($r.description) { $r.description } else { $r.title })
    category                = $(if ($r.category) { $r.category } else { $null })
    probability             = $prob
    impact                  = $imp
    score                   = ($levelScore[$prob] * $levelScore[$imp])
    response                = $(if ($r.response) { $r.response } else { 'mitigate' })
    status                  = 'open'
    owner                   = [ordered]@{ party = 'internal'; person = $ownerPerson }
    mitigation_action_cards = @()
    raised                  = $today
  }
  ($card | ConvertTo-Json -Depth 6) | Set-Content (Join-Path $projDir "risks/$id.json") -Encoding utf8
}
if ($n) { Write-Host "  risks: $n" }

# 5. milestones
$n = 0
foreach ($m in @($I.milestones)) {
  if (-not $m.name -or -not $m.target_date) { continue }
  $n++; $id = "MS-$cc-$pc-$(Pad3 $n)"
  $card = [ordered]@{
    schema_version = 1
    id             = $id
    project_id     = $projId
    name           = $m.name
    target_date    = $m.target_date
    baseline_date  = $m.target_date
    status         = 'planned'
    gating         = [bool]$m.gating
  }
  ($card | ConvertTo-Json -Depth 6) | Set-Content (Join-Path $projDir "milestones/$id.json") -Encoding utf8
}
if ($n) { Write-Host "  milestones: $n" }

Write-Host ("Done. Project scaffolded at: " + $projDir) -ForegroundColor Green
Write-Host "Next: rebuild-index.ps1 ; generate-portal.ps1 ; generate-dashboard.ps1"
