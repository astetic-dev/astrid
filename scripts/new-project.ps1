# new-project.ps1
# Scaffolds a new project under projects/<customer>/<folder>/: every card-type folder
# plus a starter project.json (valid against project-card-v1). PowerShell 7+.
#
# Usage:
#   pwsh -File scripts/new-project.ps1 -Customer ACME -Folder cloud-migration -ProjectCode CLOUD -Title "Acme cloud migration"
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Customer,
  [Parameter(Mandatory)][string]$Folder,
  [Parameter(Mandatory)][string]$ProjectCode,
  [string]$Title,
  [string]$Root = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'
$rootAbs = (Resolve-Path $Root).Path
$projRoot = Join-Path $rootAbs ("projects/{0}/{1}" -f $Customer, $Folder)

$dirs = @('cards', 'risks', 'deliverables', 'milestones', 'decisions', 'issues', 'meetings', 'documents')
foreach ($d in $dirs) { New-Item -ItemType Directory -Path (Join-Path $projRoot $d) -Force | Out-Null }

$pj = Join-Path $projRoot 'project.json'
if (-not (Test-Path $pj)) {
  $card = [ordered]@{
    schema_version    = 1
    id                = ("{0}-{1}" -f $Customer, $ProjectCode)
    title             = $(if ($Title) { $Title } else { $Folder })
    purpose           = 'TODO: 1-3 sentences on why this project exists.'
    scope_summary     = [ordered]@{ in_scope = @('TODO'); out_of_scope = @() }
    status            = 'initiation'
    customer          = [ordered]@{ code = $Customer; name = 'TODO' }
    stakeholders      = @([ordered]@{ name = 'TBD'; role = 'project lead'; party = 'internal' })
    action_cards_glob = ("cards/*-{0}-{1}-*.json" -f $Customer, $ProjectCode)
  }
  ($card | ConvertTo-Json -Depth 8) | Set-Content $pj -Encoding utf8
}

Write-Host ("Scaffolded: {0}" -f $projRoot) -ForegroundColor Green
Write-Host ("Folders: {0}" -f ($dirs -join ', '))
Write-Host "Next: fill in project.json, or use intake-scaffold.ps1 to populate from an intake.json."
