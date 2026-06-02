# generate-dashboard.ps1
# Builds _index/dashboard.html from cards-open.json + each card's body/log.
# Run after rebuild-index.ps1.
#
# Usage:  pwsh -File scripts/generate-dashboard.ps1 -Root <path-to-workspace> [-Open]
#
# Optional link bases — set these if you want source refs to deep-link into your
# tracker/wiki. Leave empty to render refs as plain text.
#   -IssueBase  e.g. https://your-org.atlassian.net   (issue type → /browse/KEY)
#   -WikiBase   e.g. https://your-org.atlassian.net   (doc type → /wiki/spaces/...)

[CmdletBinding()]
param(
  [string]$Root = (Get-Location).Path,
  [string]$IssueBase = '',
  [string]$WikiBase = '',
  [switch]$Open
)

$ErrorActionPreference = 'Stop'
$rootAbs = (Resolve-Path $Root).Path
$indexDir = Join-Path $rootAbs '_index'
$htmlPath = Join-Path $indexDir 'dashboard.html'

$start = Get-Date

# ---- 1. Read indexes (tolerate a missing or empty index) ----
function Read-Index($name) {
  $p = Join-Path $indexDir $name
  if (-not (Test-Path $p)) { return @() }
  $raw = Get-Content $p -Raw -Encoding utf8
  if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
  return @($raw | ConvertFrom-Json)
}
if (-not (Test-Path (Join-Path $indexDir 'cards-open.json'))) {
  Write-Warning "No index found in $indexDir — run rebuild-index.ps1 first. Building an empty dashboard."
}
$cards    = Read-Index 'cards-open.json'
$projects = Read-Index 'projects.json'

# Register cards: load the FULL card files (not just the index summary) so the
# dashboard can render rich, drill-down detail with clickable linked cards.
function Load-RegisterFull($indexName) {
  $full = @()
  foreach ($it in (Read-Index $indexName)) {
    if (-not $it.file) { continue }
    $fp = Join-Path $rootAbs ($it.file -replace '/', [string][IO.Path]::DirectorySeparatorChar)
    if (Test-Path $fp) { try { $full += (Get-Content $fp -Raw -Encoding utf8 | ConvertFrom-Json) } catch {} }
  }
  return $full
}
$register = @{
  risks        = Load-RegisterFull 'risks.json'
  issues       = Load-RegisterFull 'issues.json'
  decisions    = Load-RegisterFull 'decisions.json'
  milestones   = Load-RegisterFull 'milestones.json'
  deliverables = Load-RegisterFull 'deliverables.json'
}

# ---- 2. Enrich each card with body.md + log.jsonl + sidecar JSON fields ----
$enriched = @()
foreach ($c in $cards) {
  $sidecarPath = Join-Path $rootAbs ($c.file -replace '/', [string][IO.Path]::DirectorySeparatorChar)
  $body = ''
  $logEntries = @()
  $extra = @{ priority=''; type=''; acceptance_criteria=@(); sources=@(); tags=@(); reporter=''; created=''; updated=''; deadline_text=''; latest_update=$null }

  if (Test-Path $sidecarPath) {
    try {
      $full = Get-Content $sidecarPath -Raw -Encoding utf8 | ConvertFrom-Json
      if ($full.priority) { $extra.priority = $full.priority }
      if ($full.type) { $extra.type = $full.type }
      if ($full.acceptance_criteria) { $extra.acceptance_criteria = @($full.acceptance_criteria) }
      if ($full.sources) { $extra.sources = @($full.sources) }
      if ($full.tags) { $extra.tags = @($full.tags) }
      if ($full.reporter -and $full.reporter.person) { $extra.reporter = "$($full.reporter.party) / $($full.reporter.person)" }
      if ($full.created) { $extra.created = $full.created }
      if ($full.updated) { $extra.updated = $full.updated }
      if ($full.deadline -and $full.deadline.text) { $extra.deadline_text = $full.deadline.text }
      if ($full.latest_update) { $extra.latest_update = $full.latest_update }
    } catch {}
  }

  $mdPath = $sidecarPath -replace '\.json$', '.md'
  if (Test-Path $mdPath) { $body = Get-Content $mdPath -Raw -Encoding utf8 }

  $logPath = $sidecarPath -replace '\.json$', '.log.jsonl'
  if (Test-Path $logPath) {
    foreach ($line in Get-Content $logPath -Encoding utf8) {
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      try { $logEntries += (ConvertFrom-Json $line) } catch {}
    }
  }

  $enriched += [pscustomobject]@{
    id = $c.id; title = $c.title; status = $c.status; priority = $extra.priority; type = $extra.type
    late = $c.late; urgent = $c.urgent; stale = $c.stale; days_idle = $c.days_idle; assignee = $c.assignee; reporter = $extra.reporter
    deadline = $c.deadline; deadline_text = $extra.deadline_text; project = $c.project; file = $c.file
    body = $body; log = $logEntries; sources = $extra.sources; acceptance_criteria = $extra.acceptance_criteria
    tags = $extra.tags; created = $extra.created; updated = $extra.updated; latest_update = $extra.latest_update
  }
}

# ---- 3. Serialize (always emit a JSON array, even for 0 or 1 item) ----
function To-JsonArray($items, [int]$depth = 10) {
  $arr = @($items | Where-Object { $null -ne $_ })
  if ($arr.Count -eq 0) { return '[]' }
  $j = ConvertTo-Json -InputObject $arr -Depth $depth -Compress
  if (-not $j.StartsWith('[')) { $j = "[$j]" }
  return $j
}
$cardsJson = To-JsonArray $enriched
$projectsJson = To-JsonArray $projects
$registerJson = '{' + (($register.Keys | ForEach-Object { '"' + $_ + '":' + (To-JsonArray $register[$_]) }) -join ',') + '}'
$genDate = (Get-Date).ToString('dddd d MMMM yyyy')

# ---- 4. HTML template ----
$template = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>project-assistant · action cards</title>
<style>
  :root {
    --bg-deep: #0f172a;
    --bg-panel: rgba(255,255,255,.98);
    --bg-overlay: rgba(15,23,42,.92);
    --accent: #e11d48;
    --accent-soft: #fb7185;
    --primary: #4f46e5;
    --cyan: #0891b2;
    --text-on-dark: #f8fafc;
    --text-on-dark-dim: rgba(248,250,252,.75);
    --text-on-dark-faint: rgba(248,250,252,.5);
    --text-on-light: #0f172a;
    --text-on-light-dim: #64748b;
    --border-on-dark: rgba(255,255,255,.15);
    --border-on-light: #e2e8f0;
    --urgent-tint: #fff1f3;
    --normal-tint: #eef2ff;
    --wait-tint: #f1f5f9;
    --shadow-card: 0 8px 28px rgba(0,0,0,.18), 0 2px 6px rgba(0,0,0,.10);
    --shadow-card-hover: 0 16px 48px rgba(0,0,0,.25), 0 4px 12px rgba(0,0,0,.14);
    --transition: 240ms cubic-bezier(.4, 0, .2, 1);
    --radius: 10px;
    --radius-sm: 5px;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; height: 100%; }
  body {
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, 'Helvetica Neue', Arial, sans-serif;
    color: var(--text-on-light);
    background: linear-gradient(180deg, #1e293b 0%, #0f172a 55%, #0b1120 100%) fixed;
    min-height: 100vh;
    -webkit-font-smoothing: antialiased;
  }
  header.topbar { padding: 28px 40px 56px; color: var(--text-on-dark); }
  header.topbar .inner { display: flex; align-items: flex-start; justify-content: space-between; max-width: 1400px; margin: 0 auto; }
  header.topbar h1 { margin: 0; font-size: 30px; font-weight: 300; letter-spacing: -.5px; color: var(--text-on-dark); }
  header.topbar h1 .accent { color: var(--accent); font-weight: 600; }
  header.topbar .sub { font-size: 14px; color: var(--text-on-dark-dim); margin-top: 6px; letter-spacing: .3px; }
  header.topbar .meta { text-align: right; font-size: 13px; color: var(--text-on-dark-dim); line-height: 1.6; }
  main { max-width: 1400px; margin: 0 auto; padding: 0 40px 60px; }
  .view { animation: fadeIn .4s ease-out; }
  .view.hidden { display: none; }
  @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
  @keyframes slideInLeft { from { opacity: 0; transform: translateX(-14px); } to { opacity: 1; transform: translateX(0); } }
  @keyframes pop { from { opacity: 0; transform: scale(.94); } to { opacity: 1; transform: scale(1); } }
  @keyframes overlayIn { from { opacity: 0; } to { opacity: 1; } }
  @keyframes modalIn { from { opacity: 0; transform: translateY(20px) scale(.96); } to { opacity: 1; transform: translateY(0) scale(1); } }
  .section-title {
    color: var(--text-on-dark); font-size: 16px; font-weight: 500; text-transform: uppercase; letter-spacing: 2.5px;
    margin: 0 0 24px; padding-bottom: 14px; border-bottom: 1px solid var(--border-on-dark);
    display: flex; align-items: baseline; gap: 16px;
  }
  .section-title .total { margin-left: auto; font-size: 12px; color: var(--text-on-dark-faint); letter-spacing: 1px; }
  .project-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 24px; }
  .project-card {
    background: var(--bg-panel); border-radius: var(--radius); padding: 26px; box-shadow: var(--shadow-card); cursor: pointer;
    transition: transform var(--transition), box-shadow var(--transition); border-top: 3px solid var(--accent);
    position: relative; overflow: hidden; animation: pop .45s ease-out backwards;
  }
  .project-card:nth-child(1) { animation-delay: 60ms; } .project-card:nth-child(2) { animation-delay: 120ms; }
  .project-card:nth-child(3) { animation-delay: 180ms; } .project-card:nth-child(4) { animation-delay: 240ms; }
  .project-card:hover { transform: translateY(-4px); box-shadow: var(--shadow-card-hover); }
  .project-card:hover .arrow { transform: translateX(4px); opacity: 1; }
  .project-card .arrow { position: absolute; right: 22px; top: 24px; color: var(--accent); font-size: 22px; opacity: 0; transition: all var(--transition); }
  .project-card h2 { margin: 0 0 6px; font-size: 19px; color: var(--primary); font-weight: 600; padding-right: 30px; }
  .project-card .customer { font-size: 13px; color: var(--text-on-light-dim); margin-bottom: 18px; }
  .project-card .stats { display: flex; gap: 10px; margin-top: 18px; }
  .project-card .stat { flex: 1; padding: 10px 8px; border-radius: var(--radius-sm); text-align: center; }
  .stat-urgent { background: var(--urgent-tint); border: 1px solid #f5d0d6; }
  .stat-normal { background: var(--normal-tint); border: 1px solid #d4dcf5; }
  .stat-wait { background: var(--wait-tint); border: 1px solid var(--border-on-light); }
  .stat .n { font-size: 22px; font-weight: 700; line-height: 1; }
  .stat-urgent .n { color: var(--accent); } .stat-normal .n { color: var(--primary); } .stat-wait .n { color: var(--text-on-light-dim); }
  .stat .lbl { font-size: 10px; color: var(--text-on-light-dim); margin-top: 4px; text-transform: uppercase; letter-spacing: .6px; }
  .back-btn {
    background: rgba(255,255,255,.08); border: 1px solid var(--border-on-dark); padding: 8px 16px; border-radius: var(--radius-sm);
    color: var(--text-on-dark); cursor: pointer; font-size: 13px; font-weight: 500; transition: all var(--transition);
    display: inline-flex; align-items: center; gap: 8px;
  }
  .back-btn:hover { border-color: var(--accent); background: rgba(225,29,72,.18); }
  .detail-header { margin-bottom: 28px; display: flex; align-items: center; gap: 24px; color: var(--text-on-dark); }
  .detail-title { flex: 1; }
  .detail-title h2 { margin: 0; color: var(--text-on-dark); font-size: 26px; font-weight: 400; }
  .detail-title .customer { color: var(--text-on-dark-dim); font-size: 14px; margin-top: 4px; letter-spacing: .3px; }
  .columns { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 22px; }
  @media (max-width: 1100px) { .columns { grid-template-columns: 1fr; } }
  .col { background: var(--bg-panel); border-radius: var(--radius); box-shadow: var(--shadow-card); padding: 20px; min-height: 220px; }
  .col-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; padding-bottom: 12px; border-bottom: 2px solid var(--col-accent, var(--border-on-light)); }
  .col-header h3 { margin: 0; font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 1.2px; }
  .col-urgent .col-header { --col-accent: var(--accent); } .col-urgent .col-header h3 { color: var(--accent); }
  .col-normal .col-header { --col-accent: var(--primary); } .col-normal .col-header h3 { color: var(--primary); }
  .col-wait .col-header { --col-accent: #64748b; } .col-wait .col-header h3 { color: #64748b; }
  .col-header .count { background: var(--col-accent, #64748b); color: white; padding: 3px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; min-width: 26px; text-align: center; }
  .card { background: var(--card-bg, white); border-radius: var(--radius-sm); padding: 12px 14px; margin-bottom: 10px; border-left: 3px solid var(--card-accent, var(--text-on-light-dim)); transition: all var(--transition); cursor: pointer; animation: slideInLeft .35s ease-out backwards; }
  .col-urgent .card { --card-bg: var(--urgent-tint); --card-accent: var(--accent); }
  .col-normal .card { --card-bg: var(--normal-tint); --card-accent: var(--primary); }
  .col-wait .card { --card-bg: var(--wait-tint); --card-accent: #64748b; }
  .card:hover { transform: translateX(4px); box-shadow: 0 4px 14px rgba(0,0,0,.10); }
  .card .id { font-size: 10px; color: var(--text-on-light-dim); font-family: 'Consolas', monospace; margin-bottom: 4px; letter-spacing: .3px; }
  .card .title { font-size: 14px; font-weight: 500; line-height: 1.35; margin-bottom: 8px; color: var(--text-on-light); }
  .card .meta { display: flex; gap: 8px; font-size: 11px; color: var(--text-on-light-dim); flex-wrap: wrap; align-items: center; }
  .card .meta .deadline { font-weight: 600; } .card .meta .deadline.late { color: var(--accent); }
  .card .meta .status { text-transform: uppercase; letter-spacing: .5px; font-size: 9px; background: rgba(0,0,0,.06); padding: 2px 6px; border-radius: 3px; }
  .card .flags { margin-left: auto; }
  .col-empty { text-align: center; color: var(--text-on-light-dim); font-size: 13px; padding: 30px 16px; opacity: .55; }
  .overlay { position: fixed; inset: 0; z-index: 1000; background: var(--bg-overlay); backdrop-filter: blur(8px); display: flex; align-items: flex-start; justify-content: center; padding: 60px 24px; overflow-y: auto; animation: overlayIn .25s ease-out; }
  .overlay.hidden { display: none; }
  .modal { background: var(--bg-panel); border-radius: var(--radius); max-width: 920px; width: 100%; box-shadow: 0 24px 60px rgba(0,0,0,.4); overflow: hidden; animation: modalIn .3s cubic-bezier(.4,0,.2,1); }
  .modal-header { padding: 28px 32px 20px; background: linear-gradient(135deg, var(--primary) 0%, #312e81 100%); color: white; position: relative; }
  .modal-header::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px; background: linear-gradient(90deg, var(--accent), var(--cyan)); }
  .modal-close { position: absolute; top: 18px; right: 22px; background: rgba(255,255,255,.12); border: none; color: white; width: 34px; height: 34px; border-radius: 50%; cursor: pointer; font-size: 20px; line-height: 1; transition: all var(--transition); }
  .modal-close:hover { background: var(--accent); transform: rotate(90deg); }
  .modal-id { font-family: 'Consolas', monospace; font-size: 12px; color: rgba(255,255,255,.7); letter-spacing: 1px; margin-bottom: 6px; }
  .modal-title { font-size: 22px; font-weight: 500; margin: 0; line-height: 1.3; padding-right: 60px; }
  .modal-badges { display: flex; gap: 8px; margin-top: 14px; flex-wrap: wrap; }
  .badge { font-size: 11px; padding: 4px 10px; border-radius: 999px; font-weight: 600; letter-spacing: .5px; text-transform: uppercase; background: rgba(255,255,255,.15); color: white; }
  .badge-status { background: rgba(255,255,255,.20); }
  .badge-urgent { background: var(--accent); }
  .badge-late { background: #f59e0b; }
  .badge-priority-high { background: rgba(225,29,72,.85); }
  .badge-priority-medium { background: rgba(255,255,255,.25); }
  .badge-priority-low { background: rgba(255,255,255,.12); }
  .modal-body { padding: 28px 32px 32px; max-height: calc(100vh - 280px); overflow-y: auto; }
  .modal-grid { display: grid; grid-template-columns: 200px 1fr; gap: 10px 22px; margin-bottom: 24px; font-size: 14px; }
  .modal-grid .lbl { color: var(--text-on-light-dim); font-size: 12px; text-transform: uppercase; letter-spacing: 1px; padding-top: 2px; }
  .modal-grid .val { color: var(--text-on-light); } .modal-grid .val.late { color: var(--accent); font-weight: 600; }
  .modal-section { margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--border-on-light); }
  .modal-section h3 { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; color: var(--primary); margin: 0 0 12px; }
  .modal-section .body-md { font-size: 14px; line-height: 1.6; color: #2a3340; white-space: pre-wrap; }
  .modal-section .body-md h2 { font-size: 15px; font-weight: 700; color: var(--primary); margin: 14px 0 6px; text-transform: uppercase; letter-spacing: 1px; }
  .modal-section ul { padding-left: 22px; margin: 6px 0; } .modal-section li { margin: 4px 0; }
  .modal-section .tag { display: inline-block; background: var(--primary); color: white; font-size: 11px; padding: 3px 10px; border-radius: 999px; margin: 0 4px 4px 0; }
  .modal-section .source { background: var(--wait-tint); border-left: 3px solid var(--cyan); padding: 8px 12px; margin-bottom: 6px; border-radius: 3px; font-size: 13px; }
  .modal-section .source .type { display: inline-block; font-size: 10px; text-transform: uppercase; background: var(--primary); color: white; padding: 1px 6px; border-radius: 3px; margin-right: 8px; letter-spacing: .5px; }
  .modal-section .source .ref { font-family: 'Consolas', monospace; font-size: 12px; }
  .modal-section .source a.ref-link { font-family: 'Consolas', monospace; font-size: 12px; color: var(--primary); text-decoration: none; border-bottom: 1px dotted var(--primary); transition: color var(--transition), border-color var(--transition); }
  .modal-section .source a.ref-link:hover { color: var(--accent); border-bottom-color: var(--accent); }
  .modal-section .source a.ref-link::after { content: ' \2197'; font-size: 10px; opacity: .6; }
  .modal-section .source .note { display: block; color: var(--text-on-light-dim); font-size: 12px; margin-top: 4px; font-style: italic; }
  .latest-update { background: linear-gradient(135deg, #fff8e6 0%, #fffbf0 100%); border-left: 4px solid var(--accent); border-radius: var(--radius-sm); padding: 14px 18px; margin: 18px 0 24px; }
  .latest-update .lu-head { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; font-size: 12px; color: var(--text-on-light-dim); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
  .latest-update .lu-head strong { color: var(--accent); font-size: 13px; letter-spacing: 1.2px; }
  .latest-update .lu-head .lu-date { font-family: 'Consolas', monospace; font-size: 12px; color: var(--text-on-light); }
  .latest-update .lu-head .lu-by { color: var(--text-on-light-dim); font-size: 12px; text-transform: none; letter-spacing: 0; }
  .latest-update .lu-body { font-size: 14px; line-height: 1.55; color: #2a3340; }
  .latest-update .lu-body ul { padding-left: 22px; margin: 4px 0; } .latest-update .lu-body li { margin: 3px 0; }
  .modal-section .log-entry { border-left: 2px solid var(--cyan); padding: 6px 12px; margin-bottom: 8px; background: rgba(8,145,178,.07); font-size: 13px; }
  .modal-section .log-entry .ts { font-family: 'Consolas', monospace; font-size: 11px; color: var(--text-on-light-dim); margin-right: 10px; }
  .modal-section .log-entry .who { background: var(--primary); color: white; font-size: 10px; padding: 1px 6px; border-radius: 3px; text-transform: uppercase; letter-spacing: .5px; margin-right: 8px; }
  .modal-section .log-entry .action { font-weight: 600; color: var(--accent); margin-right: 6px; }
  .register { margin-top: 30px; }
  .register.hidden { display: none; }
  .register-title { color: var(--text-on-dark); font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: 2px; margin: 0 0 16px; padding-bottom: 10px; border-bottom: 1px solid var(--border-on-dark); }
  .reg-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 18px; }
  .reg-group { background: var(--bg-panel); border-radius: var(--radius); box-shadow: var(--shadow-card); padding: 16px 18px; }
  .reg-group h4 { margin: 0 0 10px; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.2px; color: var(--primary); display: flex; justify-content: space-between; align-items: center; }
  .reg-group h4 .cnt { background: var(--primary); color: #fff; border-radius: 999px; font-size: 11px; padding: 1px 8px; }
  .reg-item { padding: 8px 0; border-top: 1px solid var(--border-on-light); }
  .reg-item:first-of-type { border-top: none; }
  .reg-item .rid { font-family: 'Consolas', monospace; font-size: 10px; color: var(--text-on-light-dim); letter-spacing: .3px; }
  .reg-item .rtitle { color: var(--text-on-light); font-size: 13px; line-height: 1.35; margin: 2px 0; }
  .reg-item .rmeta { font-size: 11px; color: var(--text-on-light-dim); display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
  .reg-item .rstatus { text-transform: uppercase; letter-spacing: .5px; font-size: 9px; background: rgba(0,0,0,.06); padding: 1px 6px; border-radius: 3px; }
  .reg-item.clickable { cursor: pointer; border-radius: var(--radius-sm); margin: 0 -8px; padding: 8px; transition: background var(--transition); }
  .reg-item.clickable:hover { background: var(--normal-tint); }
  .chip { display: inline-block; font-family: 'Consolas', monospace; font-size: 11px; background: var(--normal-tint); color: var(--primary); border: 1px solid #d4dcf5; border-radius: 4px; padding: 1px 7px; margin: 2px 4px 2px 0; cursor: pointer; transition: all var(--transition); }
  .chip:hover { background: var(--primary); color: #fff; border-color: var(--primary); }
  .chip.plain { cursor: default; color: var(--text-on-light-dim); background: var(--wait-tint); border-color: var(--border-on-light); }
  .modal-linkrow { margin: 8px 0; }
  .modal-linkrow .lk-label { display: block; color: var(--text-on-light-dim); font-size: 11px; text-transform: uppercase; letter-spacing: .8px; margin-bottom: 4px; }
  .report-badge { font-size: 10px; padding: 2px 8px; border-radius: 999px; font-weight: 600; letter-spacing: .4px; text-transform: uppercase; }
  .report-ok { background: #e6f4ea; color: #137333; }
  .report-due { background: var(--urgent-tint); color: var(--accent); }
  .detail-report { color: var(--text-on-dark-dim); font-size: 13px; margin-top: 8px; display: flex; gap: 10px; align-items: center; }
  .detail-report .report-due { background: rgba(225,29,72,.22); color: var(--accent-soft); }
  .detail-report .report-ok { background: rgba(19,115,51,.22); color: #8fe0a6; }
  .card .meta .stale { color: #b45309; font-weight: 600; }
  footer { text-align: center; padding: 32px; font-size: 12px; color: var(--text-on-dark-faint); }
  footer code { background: rgba(255,255,255,.08); padding: 2px 6px; border-radius: 3px; font-family: 'Consolas', monospace; }
</style>
</head>
<body>

<header class="topbar">
  <div class="inner">
    <div>
      <h1>action<span class="accent">.</span>cards</h1>
      <div class="sub">work in progress, at a glance</div>
    </div>
    <div class="meta" id="meta-info"></div>
  </div>
</header>

<main>
  <section class="view" id="view-grid">
    <h2 class="section-title">Active projects <span class="total" id="total-info"></span></h2>
    <div class="project-grid" id="project-grid"></div>
  </section>

  <section class="view hidden" id="view-detail">
    <div class="detail-header">
      <button class="back-btn" onclick="showGrid()">&larr; Back to projects</button>
      <div class="detail-title"><h2 id="detail-title"></h2><div class="customer" id="detail-customer"></div><div class="detail-report" id="detail-report"></div></div>
    </div>
    <div class="columns">
      <div class="col col-urgent"><div class="col-header"><h3>Urgent / Late</h3><span class="count" id="count-urgent">0</span></div><div id="col-urgent"></div></div>
      <div class="col col-normal"><div class="col-header"><h3>In progress</h3><span class="count" id="count-normal">0</span></div><div id="col-normal"></div></div>
      <div class="col col-wait"><div class="col-header"><h3>Waiting / Planned</h3><span class="count" id="count-wait">0</span></div><div id="col-wait"></div></div>
    </div>
    <div class="register hidden" id="register"></div>
  </section>
</main>

<div class="overlay hidden" id="overlay" onclick="if (event.target === this) closeModal()"><div class="modal" id="modal"></div></div>

<footer>Generated <span id="gen-date"></span> &middot; source: <code>_index/cards-open.json</code> + per-card body/log</footer>

<script>
const CARDS = __CARDS_JSON__;
const PROJECTS_META = __PROJECTS_JSON__;
const ISSUE_BASE = '__ISSUE_BASE__';
const WIKI_BASE = '__WIKI_BASE__';
const REGISTER = __REGISTER_JSON__;

document.getElementById('meta-info').innerHTML = '__GEN_DATE__';
document.getElementById('gen-date').textContent = '__GEN_DATE__';
document.getElementById('total-info').textContent = CARDS.length + ' open cards';

function projectIdFromCard(c) { return c.project ? c.project.replace('/', '-') : null; }
function reportBadge(p) {
  if (p.reporting_overdue) return '<span class="report-badge report-due">report due</span>';
  if (p.last_reported) return `<span class="report-badge report-ok">reported ${escapeHtml(p.last_reported)}</span>`;
  return '';
}
function classify(c) {
  if (c.urgent || c.late) return 'urgent';
  if (['WAIT', 'PLAN', 'BLOCKED'].includes(c.status)) return 'wait';
  return 'normal';
}
function escapeHtml(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch])); }
function escapeAttr(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch])); }
function projectDirOf(card) {
  if (!card || !card.file) return null;
  return card.file.replace(/\\/g, '/').replace(/\/cards\/[^/]+$/, '');
}
function refLooksLikeFile(ref) {
  if (!ref) return false;
  if (/^https?:\/\//i.test(ref)) return false;
  return /^(input|cards|output|review|kennis|docs|meetings|notes|drafts)\//i.test(ref);
}
function renderSourceRef(s, card) {
  const ref = s.ref || '';
  const type = (s.type || '').toLowerCase();
  let href = null;
  if (/^https?:\/\//i.test(ref)) { href = ref; }
  else if (type === 'issue' && ISSUE_BASE) { const m = ref.match(/^([A-Z][A-Z0-9]+-\d+)/); if (m) href = ISSUE_BASE + '/browse/' + m[1]; }
  else if (type === 'doc' && WIKI_BASE) { const m = ref.match(/^([A-Z][A-Z0-9]+)\/(\d+)/); if (m) href = WIKI_BASE + '/wiki/spaces/' + m[1] + '/pages/' + m[2]; }
  if (!href && refLooksLikeFile(ref)) { const pd = projectDirOf(card); if (pd) href = '../' + pd + '/' + ref; }
  if (href) { return '<a href="' + escapeAttr(href) + '" target="_blank" rel="noopener" class="ref-link">' + escapeHtml(ref) + '</a>'; }
  return '<span class="ref">' + escapeHtml(ref) + '</span>';
}
function shortName(s, max=28) { if (!s) return ''; const tail = s.split(' / ').pop(); return tail.length > max ? tail.slice(0, max-1) + '…' : tail; }
function sortCards(cards) {
  return [...cards].sort((a, b) => {
    if (a.urgent !== b.urgent) return b.urgent - a.urgent;
    const da = a.deadline || '9999-12-31'; const db = b.deadline || '9999-12-31';
    if (da !== db) return da.localeCompare(db);
    return a.id.localeCompare(b.id);
  });
}
function renderProjectGrid() {
  const active = PROJECTS_META.filter(p => !['done','cancelled'].includes(p.status));
  const counts = {};
  for (const p of active) counts[p.id] = { urgent: 0, normal: 0, wait: 0, total: 0 };
  for (const c of CARDS) { const pid = projectIdFromCard(c); if (!counts[pid]) continue; counts[pid][classify(c)]++; counts[pid].total++; }
  active.sort((a, b) => (counts[b.id].urgent - counts[a.id].urgent) || (counts[b.id].total - counts[a.id].total));
  document.getElementById('project-grid').innerHTML = active.map(p => {
    const c = counts[p.id];
    return `
      <div class="project-card" onclick="showProject('${p.id}')">
        <div class="arrow">&rarr;</div>
        <h2>${escapeHtml(p.title)}</h2>
        <div class="customer">${escapeHtml(p.customer || p.id)} ${reportBadge(p)}</div>
        <div class="stats">
          <div class="stat stat-urgent"><div class="n">${c.urgent}</div><div class="lbl">Urgent</div></div>
          <div class="stat stat-normal"><div class="n">${c.normal}</div><div class="lbl">Normal</div></div>
          <div class="stat stat-wait"><div class="n">${c.wait}</div><div class="lbl">Waiting</div></div>
        </div>
      </div>`;
  }).join('') || '<div class="col-empty" style="color:var(--text-on-dark-faint)">No active projects with open cards yet.</div>';
}
function renderCard(c) {
  const flags = [];
  if (c.urgent) flags.push('🔥');
  if (c.late) flags.push('⚠');
  if (c.stale) flags.push('💤');
  const deadlineHtml = c.deadline ? `<span class="deadline ${c.late ? 'late' : ''}">${c.deadline}</span>` : '';
  const eigHtml = c.assignee ? `<span>👤 ${escapeHtml(shortName(c.assignee))}</span>` : '';
  return `
    <div class="card" onclick="openCard('${c.id}')">
      <div class="id">${c.id}</div>
      <div class="title">${escapeHtml(c.title)}</div>
      <div class="meta">${deadlineHtml}${eigHtml}<span class="status">${c.status}</span>${flags.length ? `<span class="flags">${flags.join(' ')}</span>` : ''}</div>
    </div>`;
}
function regTitleOf(it) { return it.title || it.name || ''; }
function renderRegister(pid) {
  const el = document.getElementById('register');
  const groups = [
    { label: 'Risks',        items: (REGISTER.risks        || []).filter(x => x.project_id === pid), meta: r => [ (r.probability && r.impact) ? `${r.probability}×${r.impact}` : '', (r.score != null) ? 'score ' + r.score : '', r.response ].filter(Boolean).join(' · ') },
    { label: 'Issues',       items: (REGISTER.issues       || []).filter(x => x.project_id === pid), meta: r => [ r.severity ? 'sev ' + r.severity : '', r.priority ? 'prio ' + r.priority : '', r.type ].filter(Boolean).join(' · ') },
    { label: 'Decisions',    items: (REGISTER.decisions    || []).filter(x => x.project_id === pid), meta: r => [ r.cynefin_domain, r.date ].filter(Boolean).join(' · ') },
    { label: 'Milestones',   items: (REGISTER.milestones   || []).filter(x => x.project_id === pid), meta: r => [ r.target_date ? 'target ' + r.target_date : '', (r.gate === true) ? 'gate' : '' ].filter(Boolean).join(' · ') },
    { label: 'Deliverables', items: (REGISTER.deliverables || []).filter(x => x.project_id === pid), meta: r => [ r.due_date ? 'due ' + r.due_date : '' ].filter(Boolean).join(' · ') }
  ].filter(g => g.items.length);
  if (!groups.length) { el.classList.add('hidden'); el.innerHTML = ''; return; }
  el.classList.remove('hidden');
  el.innerHTML = '<h3 class="register-title">Project register</h3><div class="reg-grid">' + groups.map(g => `
    <div class="reg-group"><h4>${g.label}<span class="cnt">${g.items.length}</span></h4>
      ${g.items.map(it => { const m = g.meta(it); return `<div class="reg-item clickable" onclick="openAny('${it.id}')"><div class="rid">${escapeHtml(it.id)}</div><div class="rtitle">${escapeHtml(regTitleOf(it))}</div><div class="rmeta"><span class="rstatus">${escapeHtml(it.status || '')}</span>${m ? `<span>${escapeHtml(m)}</span>` : ''}</div></div>`; }).join('')}
    </div>`).join('') + '</div>';
}

// ----- drill-down navigation across all card types -----
function findRegister(id) {
  for (const k of Object.keys(REGISTER)) { const f = (REGISTER[k] || []).find(x => x.id === id); if (f) return f; }
  return null;
}
function openAny(id) {
  if (!id) return;
  if (/^(ISS|RISK|DEC|MS|DLV)-/.test(id)) return openRegister(id);
  if (/^MTG-/.test(id)) return;               // meetings have no modal here
  if (CARDS.find(c => c.id === id)) return openCard(id);   // action-card
  // action-card not in the open set (e.g. DONE) — show a stub
  alert(id + ' is not in the open set (it may be done or in another project).');
}
function chip(id) { return id ? `<span class="chip" onclick="event.stopPropagation();openAny('${escapeAttr(id)}')">${escapeHtml(id)}</span>` : ''; }
function chipsRow(label, arr) {
  const list = (arr || []).filter(Boolean);
  if (!list.length) return '';
  return `<div class="modal-linkrow"><span class="lk-label">${label}</span>${list.map(chip).join('')}</div>`;
}
function openRegister(id) {
  const c = findRegister(id);
  if (!c) return;
  const kind = id.split('-')[0];
  const titles = { RISK: 'Risk', ISS: 'Issue', DEC: 'Decision', MS: 'Milestone', DLV: 'Deliverable' };
  const ownerStr = o => o ? [o.party, o.person].filter(Boolean).join(' / ') : '';
  let gridRows = [['Type', titles[kind] || kind], ['Status', c.status || '—']];
  let prose = '', links = '';

  if (kind === 'RISK') {
    gridRows.push(['Probability × Impact', [c.probability, c.impact].filter(Boolean).join(' × ') + (c.score != null ? `  (score ${c.score})` : '')]);
    gridRows.push(['Response', c.response || '—'], ['Owner', ownerStr(c.owner) || '—'], ['Raised', c.raised || '—'], ['Review due', c.review_due || '—']);
    prose = section('Description', c.description) + section('Mitigation', c.mitigation) + section('Trigger', c.trigger) + section('Residual', c.residual);
    links = chipsRow('Mitigated by (actions)', c.mitigation_action_cards) + chipsRow('Realized as issue', c.realized_as_issue ? [c.realized_as_issue] : []);
  } else if (kind === 'ISS') {
    gridRows.push(['Severity (technical)', c.severity || '—'], ['Priority (business)', c.priority || '—'], ['Kind', c.type || '—'], ['Environment', c.environment || '—'], ['Reporter', ownerStr(c.reporter) || '—'], ['Raised', c.raised || '—'], ['Resolution', c.resolution || '—']);
    prose = section('Description', c.description) + (c.steps_to_reproduce && c.steps_to_reproduce.length ? `<div class="modal-section"><h3>Steps to reproduce</h3><ul>${c.steps_to_reproduce.map(s => `<li>${escapeHtml(s)}</li>`).join('')}</ul></div>` : '') + section('Expected', c.expected) + section('Actual', c.actual);
    links = chipsRow('Work (actions)', c.action_cards) + chipsRow('Duplicate of', c.duplicate_of ? [c.duplicate_of] : []);
  } else if (kind === 'DEC') {
    gridRows.push(['Date', c.date || '—'], ['Cynefin domain', c.cynefin_domain || '—'], ['Decision-makers', (c.decision_makers || []).map(ownerStr).filter(Boolean).join(', ') || '—']);
    prose = section('Context', c.context) + section('Decision', c.decision) + section('Consequences', c.consequences)
      + ((c.options_considered && c.options_considered.length) ? `<div class="modal-section"><h3>Options considered</h3>${c.options_considered.map(o => `<div class="source"><strong>${escapeHtml(o.option)}${o.chosen ? ' ✓' : ''}</strong>${(o.pros||[]).length ? '<br>+ ' + o.pros.map(escapeHtml).join('<br>+ ') : ''}${(o.cons||[]).length ? '<br>− ' + o.cons.map(escapeHtml).join('<br>− ') : ''}</div>`).join('')}</div>` : '');
    links = chipsRow('Resolves decision-action', c.resolves_action_card ? [c.resolves_action_card] : []) + chipsRow('Drives (actions)', c.action_cards) + chipsRow('Decided at meeting', c.decided_at_meeting ? [c.decided_at_meeting] : []) + chipsRow('Supersedes', c.supersedes) + chipsRow('Superseded by', c.superseded_by ? [c.superseded_by] : []);
  } else if (kind === 'MS') {
    gridRows.push(['Target', c.target_date || '—'], ['Baseline', c.baseline_date || '—'], ['Actual', c.actual_date || '—'], ['Gate', c.gate ? 'yes' : 'no'], ['Owner', ownerStr(c.owner) || '—']);
    prose = section('Description', c.description) + ((c.gate_criteria && c.gate_criteria.length) ? `<div class="modal-section"><h3>Gate criteria</h3><ul>${c.gate_criteria.map(x => `<li>${escapeHtml(x)}</li>`).join('')}</ul></div>` : '');
    links = chipsRow('Deliverables', c.deliverables) + chipsRow('Threatened by (issues)', c.issues) + chipsRow('Actions', c.action_cards);
  } else if (kind === 'DLV') {
    gridRows.push(['Format', c.format || '—'], ['Owner', ownerStr(c.owner) || '—'], ['Recipient', ownerStr(c.recipient) || '—'], ['Due', c.due_date || '—'], ['Sign-off', c.sign_off ? `${escapeHtml(c.sign_off.by)} (${c.sign_off.date})` : '—']);
    prose = section('Description', c.description) + ((c.acceptance_criteria && c.acceptance_criteria.length) ? `<div class="modal-section"><h3>Acceptance criteria</h3><ul>${c.acceptance_criteria.map(x => `<li>${escapeHtml(x)}</li>`).join('')}</ul></div>` : '') + section('Rejection note', c.rejection_note);
    links = chipsRow('Rolls up to milestone', c.milestone_id ? [c.milestone_id] : []) + chipsRow('Issues against it', c.issues) + chipsRow('Produced by (actions)', c.action_cards);
  }

  const grid = `<div class="modal-grid">${gridRows.map(r => `<div class="lbl">${escapeHtml(r[0])}</div><div class="val">${typeof r[1] === 'string' ? escapeHtml(r[1]) : r[1]}</div>`).join('')}</div>`;
  const linksBlock = links ? `<div class="modal-section"><h3>Linked cards</h3>${links}</div>` : '';
  document.getElementById('modal').innerHTML = `
    <div class="modal-header">
      <button class="modal-close" onclick="closeModal()">&times;</button>
      <div class="modal-id">${escapeHtml(c.id)}</div>
      <h2 class="modal-title">${escapeHtml(regTitleOf(c))}</h2>
      <div class="modal-badges"><span class="badge badge-status">${escapeHtml(c.status || '')}</span><span class="badge">${escapeHtml(titles[kind] || kind)}</span></div>
    </div>
    <div class="modal-body">${grid}${linksBlock}${prose}</div>`;
  document.getElementById('overlay').classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}
function section(title, text) { return text ? `<div class="modal-section"><h3>${escapeHtml(title)}</h3><div class="body-md">${renderBodyMd(text)}</div></div>` : ''; }

function showProject(pid) {
  const project = PROJECTS_META.find(p => p.id === pid);
  if (!project) return;
  document.getElementById('detail-title').textContent = project.title;
  document.getElementById('detail-customer').textContent = project.customer || pid;
  const repBadge = reportBadge(project);
  const repInfo = project.report_cadence
    ? `<span>reporting: ${escapeHtml(project.report_cadence)}${project.days_since_reported != null ? ` · last reported ${project.days_since_reported}d ago` : ' · never reported'}${project.report_next_due ? ` · next due ${escapeHtml(project.report_next_due)}` : ''}</span>`
    : '';
  document.getElementById('detail-report').innerHTML = (repBadge || repInfo) ? (repBadge + repInfo) : '';
  const my = CARDS.filter(c => projectIdFromCard(c) === pid);
  const buckets = { urgent: [], normal: [], wait: [] };
  for (const c of my) buckets[classify(c)].push(c);
  for (const k of Object.keys(buckets)) buckets[k] = sortCards(buckets[k]);
  const rc = (id, list, empty) => {
    const el = document.getElementById(id);
    if (list.length === 0) el.innerHTML = `<div class="col-empty">${empty}</div>`;
    else el.innerHTML = list.map((c, i) => renderCard(c).replace('<div class="card"', `<div class="card" style="animation-delay:${i*30}ms"`)).join('');
  };
  rc('col-urgent', buckets.urgent, 'Nothing urgent — keep it that way 🎯');
  rc('col-normal', buckets.normal, 'Nothing in progress');
  rc('col-wait',   buckets.wait,   'Nothing in the waiting room');
  document.getElementById('count-urgent').textContent = buckets.urgent.length;
  document.getElementById('count-normal').textContent = buckets.normal.length;
  document.getElementById('count-wait').textContent = buckets.wait.length;
  renderRegister(pid);
  document.getElementById('view-grid').classList.add('hidden');
  document.getElementById('view-detail').classList.remove('hidden');
  window.scrollTo({ top: 0, behavior: 'smooth' });
}
function showGrid() {
  document.getElementById('view-detail').classList.add('hidden');
  document.getElementById('view-grid').classList.remove('hidden');
  document.getElementById('view-grid').style.animation = 'none';
  void document.getElementById('view-grid').offsetWidth;
  document.getElementById('view-grid').style.animation = '';
}
function renderBodyMd(md) {
  if (!md) return '<em>no description</em>';
  let html = escapeHtml(md);
  html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
  html = html.replace(/^- (.+)$/gm, '<li>$1</li>');
  html = html.replace(/(<li>.+<\/li>\n?)+/g, m => '<ul>' + m + '</ul>');
  html = html.replace(/\[\[(.+?)\]\]/g, '<code>$1</code>');
  return html;
}
function openCard(id) {
  const c = CARDS.find(x => x.id === id);
  if (!c) return;
  const badges = [];
  badges.push(`<span class="badge badge-status">${c.status}</span>`);
  if (c.priority) badges.push(`<span class="badge badge-priority-${c.priority}">${c.priority}</span>`);
  if (c.urgent) badges.push(`<span class="badge badge-urgent">urgent</span>`);
  if (c.late) badges.push(`<span class="badge badge-late">late</span>`);
  if (c.stale) badges.push(`<span class="badge" style="background:#b45309">stale${c.days_idle != null ? ' · ' + c.days_idle + 'd' : ''}</span>`);
  if (c.type) badges.push(`<span class="badge">${c.type}</span>`);
  const dl = c.deadline ? `<span class="${c.late ? 'val late' : 'val'}">${c.deadline}${c.deadline_text ? ' — ' + escapeHtml(c.deadline_text) : ''}</span>` : '<span class="val">—</span>';
  const grid = `
    <div class="modal-grid">
      <div class="lbl">Project</div><div class="val">${escapeHtml(c.project || '—')}</div>
      <div class="lbl">Assignee</div><div class="val">${escapeHtml(c.assignee || '—')}</div>
      <div class="lbl">Reporter</div><div class="val">${escapeHtml(c.reporter || '—')}</div>
      <div class="lbl">Deadline</div>${dl}
      <div class="lbl">Created</div><div class="val">${escapeHtml((c.created || '—').slice(0,10))}</div>
      <div class="lbl">Updated</div><div class="val">${escapeHtml((c.updated || '—').slice(0,10))}</div>
    </div>`;
  const tags = (c.tags || []).length ? `<div class="modal-section"><h3>Tags</h3>${c.tags.map(t => `<span class="tag">${escapeHtml(t)}</span>`).join('')}</div>` : '';
  const ac = (c.acceptance_criteria || []).length ? `<div class="modal-section"><h3>Acceptance criteria</h3><ul>${c.acceptance_criteria.map(x => `<li>${escapeHtml(x)}</li>`).join('')}</ul></div>` : '';
  const sources = (c.sources || []).length ? `<div class="modal-section"><h3>Sources</h3>${c.sources.map(s => `
        <div class="source"><span class="type">${escapeHtml(s.type || '?')}</span>${renderSourceRef(s, c)}${s.note ? `<span class="note">${escapeHtml(s.note)}</span>` : ''}</div>`).join('')}</div>` : '';
  const lu = c.latest_update;
  const latestUpdateHtml = (lu && lu.summary) ? `<div class="latest-update">
        <div class="lu-head"><strong>Latest update</strong>${lu.date ? `<span class="lu-date">${escapeHtml(lu.date)}</span>` : ''}${lu.by ? `<span class="lu-by">— ${escapeHtml(lu.by)}</span>` : ''}</div>
        <div class="lu-body">${renderBodyMd(lu.summary)}</div></div>` : '';
  const body = c.body ? `<div class="modal-section"><h3>Description</h3><div class="body-md">${renderBodyMd(c.body)}</div></div>` : '';
  const log = (c.log || []).length ? `<div class="modal-section"><h3>Activity log (${c.log.length})</h3>${[...c.log].reverse().map(e => `
        <div class="log-entry"><span class="ts">${escapeHtml((e.ts || '').slice(0, 16).replace('T',' '))}</span><span class="who">${escapeHtml(e.who || '?')}</span>${e.action ? `<span class="action">${escapeHtml(e.action)}</span>` : ''}${e.note ? escapeHtml(e.note) : ''}${e.from ? ` (${escapeHtml(e.from)} → ${escapeHtml(e.to || '')})` : ''}</div>`).join('')}</div>` : '';
  document.getElementById('modal').innerHTML = `
    <div class="modal-header">
      <button class="modal-close" onclick="closeModal()">&times;</button>
      <div class="modal-id">${c.id}</div>
      <h2 class="modal-title">${escapeHtml(c.title)}</h2>
      <div class="modal-badges">${badges.join('')}</div>
    </div>
    <div class="modal-body">${grid}${latestUpdateHtml}${body}${ac}${tags}${sources}${log}</div>`;
  document.getElementById('overlay').classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}
function closeModal() { document.getElementById('overlay').classList.add('hidden'); document.body.style.overflow = ''; }
renderProjectGrid();
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    if (!document.getElementById('overlay').classList.contains('hidden')) closeModal();
    else if (!document.getElementById('view-detail').classList.contains('hidden')) showGrid();
  }
});
</script>
</body>
</html>
'@

# ---- 5. Inject data ----
$html = $template.Replace('__CARDS_JSON__', $cardsJson)
$html = $html.Replace('__PROJECTS_JSON__', $projectsJson)
$html = $html.Replace('__REGISTER_JSON__', $registerJson)
$html = $html.Replace('__ISSUE_BASE__', $IssueBase)
$html = $html.Replace('__WIKI_BASE__', $WikiBase)
$html = $html.Replace('__GEN_DATE__', $genDate)

[System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))

$dur = ((Get-Date) - $start).TotalMilliseconds
$size = [int]((Get-Item $htmlPath).Length / 1024)
Write-Host ("Done: {0}  ({1} KB, {2} ms)" -f $htmlPath, $size, [int]$dur) -ForegroundColor Green

if ($Open) {
  # Cross-platform open. ($IsWindows is undefined on Windows PowerShell 5.1 → treat as Windows.)
  if ($IsMacOS)      { & open $htmlPath }
  elseif ($IsLinux)  { & xdg-open $htmlPath }
  else               { Start-Process $htmlPath }
}
