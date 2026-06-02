# rebuild-index.ps1
# Scans every card file under the workspace root and builds the indexes:
#   - _index/cards.json       (all action-cards, with auto-flags late/urgent)
#   - _index/cards-open.json  (subset: status NOT IN [DONE, CANCELLED])
#   - _index/cards-done.json  (subset: status IN [DONE, CANCELLED])
#   - _index/projects.json    (all project-cards)
#   - _index/contacts.json    (all contact-cards)
#   - _index/.last-rebuild    (timestamp metadata)
# Plus a per-project _index.json for action-cards.
#
# Usage:  pwsh -File scripts/rebuild-index.ps1 -Root <path-to-workspace>
#         (defaults to the current directory)
#
# A workspace looks like:
#   <root>/projects/<customer>/<project>/cards/*.json (+ .md + .log.jsonl)
#   <root>/projects/<customer>/<project>/project.json
#   <root>/_contacts/CONTACT-*.json
#   <root>/_index/   (generated)

[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$today = (Get-Date).Date

$rootAbs        = (Resolve-Path $Root).Path
$globalActions  = @()
$projects       = @{}
$globalProjects = @()
$globalContacts = @()

# ---------------------------------------------------------------------------
# 1. ACTION-CARDS — */cards/*.json with auto-flags
# ---------------------------------------------------------------------------
Get-ChildItem -Path $rootAbs -Recurse -Filter '*.json' -File |
    Where-Object { $_.FullName -match '[\\/]cards[\\/]' -and $_.Name -notlike '_*' } |
    ForEach-Object {
        $cardPath = $_.FullName
        try {
            $card = Get-Content $cardPath -Raw -Encoding utf8 | ConvertFrom-Json
        }
        catch {
            Write-Warning "Could not parse $cardPath : $_"
            return
        }

        # Auto-flag: late
        $late = $false
        if ($card.deadline -and $card.deadline.date) {
            try {
                $deadlineDate = [datetime]::ParseExact($card.deadline.date, 'yyyy-MM-dd', $null).Date
                if ($deadlineDate -lt $today -and $card.status -notin @('DONE', 'CANCELLED')) {
                    $late = $true
                }
            } catch { }
        }

        # Auto-flag: urgent
        $urgent = $false
        if ($card.urgent_override -eq $true)       { $urgent = $true }
        elseif ($card.urgent_override -eq $false)  { $urgent = $false }
        else {
            if ($card.priority -eq 'high')                       { $urgent = $true }
            elseif ($late -and $card.priority -eq 'medium')      { $urgent = $true }
        }

        # Write flags back into the card file (idempotent). Add the property when
        # absent — fresh cards legitimately omit the auto-flags.
        $needWrite = $false
        $curLate   = if ($card.PSObject.Properties['late'])   { $card.late }   else { $null }
        $curUrgent = if ($card.PSObject.Properties['urgent']) { $card.urgent } else { $null }
        if ($curLate -ne $late) {
            if ($card.PSObject.Properties['late']) { $card.late = $late }
            else { $card | Add-Member -NotePropertyName late -NotePropertyValue $late }
            $needWrite = $true
        }
        if ($curUrgent -ne $urgent) {
            if ($card.PSObject.Properties['urgent']) { $card.urgent = $urgent }
            else { $card | Add-Member -NotePropertyName urgent -NotePropertyValue $urgent }
            $needWrite = $true
        }
        if ($needWrite) {
            $card | ConvertTo-Json -Depth 10 | Set-Content $cardPath -Encoding utf8
            Write-Verbose "  flags updated: $($card.id)  late=$late urgent=$urgent"
        }

        $entry = [pscustomobject]@{
            id          = $card.id
            title       = $card.title
            status      = $card.status
            priority    = $card.priority
            late        = $late
            urgent      = $urgent
            assignee    = if ($card.assignee) { "$($card.assignee.party) / $($card.assignee.person)" } else { $null }
            deadline    = if ($card.deadline) { $card.deadline.date } else { $null }
            project     = if ($card.project) { "$($card.project.customer_code)/$($card.project.project_code)" } else { $null }
            file        = $cardPath.Replace($rootAbs + [IO.Path]::DirectorySeparatorChar, '').Replace('\', '/')
        }
        $globalActions += $entry

        $projDir = Split-Path (Split-Path $cardPath -Parent) -Parent
        if (-not $projects.ContainsKey($projDir)) { $projects[$projDir] = @() }
        $projects[$projDir] += $entry
    }

# Per-project _index.json (action-cards)
foreach ($projDir in $projects.Keys) {
    $idxPath = Join-Path $projDir '_index.json'
    $projects[$projDir] | ConvertTo-Json -Depth 5 | Set-Content $idxPath -Encoding utf8
    Write-Verbose "Wrote: $idxPath ($($projects[$projDir].Count) action-cards)"
}

# ---------------------------------------------------------------------------
# 2. PROJECT-CARDS — <project>/project.json
# ---------------------------------------------------------------------------
Get-ChildItem -Path $rootAbs -Recurse -Filter 'project.json' -File |
    Where-Object { $_.FullName -notmatch '[\\/]_' } |
    ForEach-Object {
        $projPath = $_.FullName
        try {
            $proj = Get-Content $projPath -Raw -Encoding utf8 | ConvertFrom-Json
        }
        catch {
            Write-Warning "Could not parse $projPath : $_"
            return
        }

        $entry = [pscustomobject]@{
            id              = $proj.id
            title           = $proj.title
            status          = $proj.status
            health_level    = if ($proj.health) { $proj.health.level } else { $null }
            health_since    = if ($proj.health) { $proj.health.since } else { $null }
            customer        = if ($proj.customer) { "$($proj.customer.code) / $($proj.customer.name)" } else { $null }
            start_date      = if ($proj.timeline) { $proj.timeline.start_date } else { $null }
            target_date     = if ($proj.timeline) { $proj.timeline.target_date } else { $null }
            go_live_planned = if ($proj.timeline) { $proj.timeline.go_live_planned } else { $null }
            classification  = $proj.classification
            risk_count      = if ($proj.risks) { @($proj.risks).Count } else { 0 }
            file            = $projPath.Replace($rootAbs + [IO.Path]::DirectorySeparatorChar, '').Replace('\', '/')
        }
        $globalProjects += $entry
        Write-Verbose "Project-card indexed: $($proj.id)"
    }

# ---------------------------------------------------------------------------
# 3. CONTACT-CARDS — _contacts/CONTACT-*.json
# ---------------------------------------------------------------------------
$contactsDir = Join-Path $rootAbs '_contacts'
if (Test-Path $contactsDir) {
    Get-ChildItem -Path $contactsDir -Filter 'CONTACT-*.json' -File |
        ForEach-Object {
            $contactPath = $_.FullName
            try {
                $contact = Get-Content $contactPath -Raw -Encoding utf8 | ConvertFrom-Json
            }
            catch {
                Write-Warning "Could not parse $contactPath : $_"
                return
            }

            $entry = [pscustomobject]@{
                id           = $contact.id
                name         = $contact.name
                organization = if ($contact.organization) { "$($contact.organization.code) / $($contact.organization.name)" } else { $null }
                role         = $contact.role
                email        = if ($contact.contact) { $contact.contact.email } else { $null }
                phone        = if ($contact.contact) { $contact.contact.phone } else { $null }
                active       = $contact.active
                departed_at  = $contact.departed_at
                involved_in  = if ($contact.involved_in) { ($contact.involved_in -join ', ') } else { '' }
                file         = $contactPath.Replace($rootAbs + [IO.Path]::DirectorySeparatorChar, '').Replace('\', '/')
            }
            $globalContacts += $entry
        }
}

# ---------------------------------------------------------------------------
# 4. OTHER CARD TYPES — risks / decisions / issues / milestones / deliverables
#    Each lives in <project>/<folder>/<PREFIX>-*.json. Indexed generically:
#    every card contributes id + project_id + a title + status + file, plus any
#    of a small set of type-specific fields it happens to carry.
# ---------------------------------------------------------------------------
$otherTypes = @(
    @{ folder = 'risks';        prefix = 'RISK-' },
    @{ folder = 'decisions';    prefix = 'DEC-'  },
    @{ folder = 'issues';       prefix = 'ISS-'  },
    @{ folder = 'milestones';   prefix = 'MS-'   },
    @{ folder = 'deliverables'; prefix = 'DLV-'  }
)
$passthrough = @('severity','priority','probability','impact','score','type',
                 'target_date','baseline_date','actual_date','due_date','gate',
                 'response','resolution','milestone_id','raised','resolved','date')
$otherIndexes = @{}
foreach ($t in $otherTypes) {
    $items = @()
    Get-ChildItem -Path $rootAbs -Recurse -Filter '*.json' -File |
        Where-Object { $_.FullName -match "[\\/]$($t.folder)[\\/]" -and $_.Name -like "$($t.prefix)*" } |
        ForEach-Object {
            $p = $_.FullName
            try { $obj = Get-Content $p -Raw -Encoding utf8 | ConvertFrom-Json }
            catch { Write-Warning "Could not parse $p : $_"; return }
            $entry = [ordered]@{
                id         = $obj.id
                project_id = $obj.project_id
                title      = if ($obj.PSObject.Properties['title']) { $obj.title } elseif ($obj.PSObject.Properties['name']) { $obj.name } else { $null }
                status     = $obj.status
                file       = $p.Replace($rootAbs + [IO.Path]::DirectorySeparatorChar, '').Replace('\', '/')
            }
            foreach ($f in $passthrough) {
                if ($obj.PSObject.Properties[$f]) { $entry[$f] = $obj.$f }
            }
            $items += [pscustomobject]$entry
        }
    $otherIndexes[$t.folder] = $items
}

# ---------------------------------------------------------------------------
# Write global indexes
# ---------------------------------------------------------------------------
$globalIdxDir = Join-Path $rootAbs '_index'
if (-not (Test-Path $globalIdxDir)) { New-Item -ItemType Directory -Path $globalIdxDir | Out-Null }

$openActions = $globalActions | Where-Object { $_.status -notin @('DONE','CANCELLED') }
$doneActions = $globalActions | Where-Object { $_.status -in @('DONE','CANCELLED') }

$globalActions  | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $globalIdxDir 'cards.json')       -Encoding utf8
$openActions    | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $globalIdxDir 'cards-open.json')  -Encoding utf8
$doneActions    | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $globalIdxDir 'cards-done.json')  -Encoding utf8
$globalProjects | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $globalIdxDir 'projects.json')    -Encoding utf8
$globalContacts | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $globalIdxDir 'contacts.json')    -Encoding utf8
foreach ($t in $otherTypes) {
    $otherIndexes[$t.folder] | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $globalIdxDir "$($t.folder).json") -Encoding utf8
}

$lastRebuildFile = Join-Path $globalIdxDir '.last-rebuild'
(Get-Date).ToString('o') | Set-Content $lastRebuildFile -Encoding utf8

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Done."
Write-Host "  Action-cards :  $($globalActions.Count) (open=$($openActions.Count), done=$($doneActions.Count))"
Write-Host "     late   = $(@($globalActions | Where-Object late).Count)"
Write-Host "     urgent = $(@($globalActions | Where-Object urgent).Count)"
Write-Host "  Project-cards:  $($globalProjects.Count)"
Write-Host "  Contact-cards:  $($globalContacts.Count)"
foreach ($t in $otherTypes) {
    $label = $t.folder.PadRight(13)
    Write-Host "  $label : $($otherIndexes[$t.folder].Count)"
}
