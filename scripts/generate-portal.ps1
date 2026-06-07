# generate-portal.ps1
# Builds _index/portal.html: a navigable project-overview portal, alongside the dashboard.
# Landing = project tiles -> a project page with a phase header (derived from status) and
# tabs (Actions / Risks / Deliverables / Documents). Action-cards, risk mitigation-actions
# and deliverable action-cards are click-through to a read-only card detail. Documents are
# shown inline (PDF/HTML/PNG/Markdown) where the browser can render them.
# Reads _index/*.json + per-project project.json + the project's documents/ folder.
# PowerShell 7+; output is a self-contained HTML file (no external assets).
#
# Usage:  pwsh -File scripts/generate-portal.ps1 -Root <workspace> [-Open]
[CmdletBinding()]
param(
  [string]$Root = (Get-Location).Path,
  [switch]$Open
)
$ErrorActionPreference = 'Stop'
$rootAbs = (Resolve-Path $Root).Path
$idx = Join-Path $rootAbs '_index'
$htmlPath = Join-Path $idx 'portal.html'

function Read-Json($name) {
  $p = Join-Path $idx $name
  if (Test-Path $p) { Get-Content $p -Raw -Encoding utf8 | ConvertFrom-Json } else { @() }
}
$projects     = Read-Json 'projects.json'
$cardsOpen    = Read-Json 'cards-open.json'
$cardsAll     = if (Test-Path (Join-Path $idx 'cards.json')) { Read-Json 'cards.json' } else { $cardsOpen }
$risks        = Read-Json 'risks.json'
$deliverables = Read-Json 'deliverables.json'

# Per-project detail (narrative + documents)
$details = @{}; $docs = @{}
foreach ($p in $projects) {
  $rel = ($p.file -replace '/', '\')
  $full = Join-Path $rootAbs $rel
  $pdir = (Split-Path $p.file -Parent)
  try { $pj = Get-Content $full -Raw -Encoding utf8 | ConvertFrom-Json } catch { continue }
  $details[$p.id] = [ordered]@{
    purpose          = $pj.purpose
    in_scope         = @($pj.scope_summary.in_scope)
    out_of_scope     = @($pj.scope_summary.out_of_scope)
    success_criteria = @($pj.success_criteria)
    references       = $pj.references
    timeline         = $pj.timeline
  }
  $docDir = Join-Path (Split-Path $full -Parent) 'documents'
  $list = @()
  if (Test-Path $docDir) {
    $all = Get-ChildItem $docDir -File | Where-Object { $_.Name -notlike '_*' -and $_.Name -notlike '~$*' }
    $srcBases = @($all | Where-Object { $_.Extension -in '.docx', '.xlsx' } | ForEach-Object { $_.BaseName.ToLower() })
    $base = '../' + ($pdir -replace '\\', '/') + '/documents/'
    foreach ($f in ($all | Sort-Object Name)) {
      $ext = $f.Extension.ToLower()
      if ($ext -notin '.docx', '.xlsx', '.pdf', '.html', '.png', '.md') { continue }
      if ($ext -eq '.pdf' -and ($srcBases -contains $f.BaseName.ToLower())) { continue }  # rendered sibling of a docx/xlsx
      $prev = $null
      if ($ext -in '.pdf', '.html', '.png', '.md') { $prev = $base + $f.Name }            # browser can render inline
      elseif ($ext -in '.docx', '.xlsx') { $prev = $base + $f.BaseName + '.pdf' }          # inline if a rendered PDF exists (see render-doc-pdfs)
      $list += [ordered]@{ file = $f.Name; rel = ($base + $f.Name); prev = $prev; ext = $ext.TrimStart('.') }
    }
  }
  $docs[$p.id] = $list
}

function J($o) { if ($null -eq $o) { '[]' } else { $o | ConvertTo-Json -Depth 12 -Compress } }
$projectsJson = J $projects
$cardsJson    = J $cardsOpen
$allCardsJson = J $cardsAll
$risksJson    = J $risks
$delivJson    = J $deliverables
$detailsJson  = ($details | ConvertTo-Json -Depth 12 -Compress); if (-not $detailsJson) { $detailsJson = '{}' }
$docsJson     = ($docs    | ConvertTo-Json -Depth 12 -Compress); if (-not $docsJson) { $docsJson = '{}' }
$dateStr = (Get-Date).ToString('yyyy-MM-dd')

$tpl = @'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Astrid | projects</title>
<style>
 :root{--red:#CC3333;--blue:#24252F;--blue2:#16171d;--accent:#8D99AE;--deep:#24252F;
   --panel:#EDF2F4;--ink:#24252F;--dim:#8D99AE;--line:#CED5D8;--soft:#F7F7F7;
   --ok:#8D99AE;--warn:#DD4A4A;--shadow:0 8px 28px rgba(0,0,0,.18),0 2px 6px rgba(0,0,0,.10);}
 *{box-sizing:border-box;} html,body{margin:0;height:100%;}
 body{font-family:'Open Sans','Segoe UI',-apple-system,Arial,sans-serif;color:var(--ink);background:var(--deep);min-height:100vh;}
 h1,h2,h3,h4,.stitle,.dtype{font-family:'Poppins','Segoe UI',Arial,sans-serif;}
 header.top{padding:26px 40px 40px;color:#EDF2F4;} header.top .inner{max-width:1380px;margin:0 auto;display:flex;justify-content:space-between;align-items:flex-start;}
 header.top h1{margin:0;font-size:30px;font-weight:300;} header.top h1 b{font-weight:700;} header.top h1 .d{color:var(--red);font-weight:800;}
 header.top .sub{font-size:14px;color:rgba(237,242,244,.75);margin-top:6px;} header.top .meta{text-align:right;font-size:13px;color:rgba(237,242,244,.7);}
 main{max-width:1380px;margin:0 auto;padding:0 40px 60px;}
 .stitle{color:#EDF2F4;font-size:13px;font-weight:500;text-transform:uppercase;letter-spacing:2px;margin:0 0 18px;padding-bottom:10px;border-bottom:1px solid rgba(237,242,244,.18);}
 .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:22px;}
 .pcard{background:var(--panel);border-radius:10px;padding:24px;box-shadow:var(--shadow);cursor:pointer;border-top:3px solid var(--blue);transition:transform .2s;}
 .pcard:hover{transform:translateY(-4px);}
 .pcard h2{margin:0 0 4px;font-size:19px;color:var(--blue);} .pcard .cust{font-size:13px;color:var(--dim);margin-bottom:14px;}
 .badges{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px;} .badge{font-size:11px;padding:3px 9px;border-radius:999px;font-weight:600;background:var(--soft);color:var(--blue);}
 .hdot{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:5px;vertical-align:-1px;}
 .stats{display:flex;gap:10px;} .stat{flex:1;text-align:center;padding:9px 6px;border-radius:6px;background:var(--soft);border:1px solid var(--line);}
 .stat .n{font-size:21px;font-weight:700;color:var(--blue);} .stat.r .n{color:var(--red);} .stat .l{font-size:10px;color:var(--dim);text-transform:uppercase;letter-spacing:.5px;margin-top:3px;}
 .back{background:rgba(237,242,244,.08);border:1px solid rgba(237,242,244,.18);color:#EDF2F4;padding:8px 16px;border-radius:6px;cursor:pointer;font-size:13px;margin-bottom:18px;}
 .back:hover{border-color:var(--red);}
 .view.hidden{display:none;}
 .phead{background:var(--panel);border-radius:10px;box-shadow:var(--shadow);overflow:hidden;margin-bottom:22px;}
 .phead .bar{background:var(--accent);color:var(--blue);padding:20px 26px;position:relative;}
 .phead .bar::after{content:'';position:absolute;left:0;right:0;bottom:0;height:4px;background:linear-gradient(90deg,var(--red) 60%,var(--blue) 60%);}
 .phead h2{margin:0;font-size:23px;font-weight:600;} .phead .cust{color:var(--blue);opacity:.75;font-size:13px;margin-top:3px;}
 .phead .pmeta{display:flex;gap:18px;flex-wrap:wrap;margin-top:12px;font-size:12px;color:var(--blue);opacity:.85;} .phead .pmeta b{opacity:1;}
 .fasen{padding:16px 26px 6px;} .fasen svg{width:100%;height:auto;display:block;}
 .tabs{display:flex;gap:4px;padding:0 18px;border-top:1px solid var(--line);}
 .tab{padding:12px 16px;cursor:pointer;font-size:13px;font-weight:600;color:var(--dim);border-bottom:3px solid transparent;}
 .tab.active{color:var(--blue);border-bottom-color:var(--red);}
 .cols{display:grid;grid-template-columns:1fr 1fr 1fr;gap:18px;} @media(max-width:1000px){.cols{grid-template-columns:1fr;}}
 .col{background:var(--panel);border-radius:10px;box-shadow:var(--shadow);padding:18px;min-height:120px;}
 .col h3{margin:0 0 12px;font-size:13px;text-transform:uppercase;letter-spacing:1px;}
 .col.u h3{color:var(--red);} .col.n h3{color:var(--blue);} .col.w h3{color:var(--dim);}
 .ac{background:var(--soft);border-left:3px solid var(--blue);border-radius:5px;padding:10px 12px;margin-bottom:9px;cursor:pointer;}
 .ac:hover{box-shadow:0 2px 10px rgba(0,0,0,.12);} .col.u .ac{border-left-color:var(--red);} .col.w .ac{border-left-color:var(--dim);}
 .ac .id{font-size:10px;color:var(--dim);font-family:Consolas,monospace;} .ac .t{font-size:14px;font-weight:500;margin:3px 0 6px;}
 .ac .m{font-size:11px;color:var(--dim);display:flex;gap:8px;flex-wrap:wrap;align-items:center;} .ac .st{background:rgba(0,0,0,.06);padding:1px 6px;border-radius:3px;text-transform:uppercase;font-size:9px;}
 .panelw{background:var(--panel);border-radius:10px;box-shadow:var(--shadow);padding:22px;}
 table.r{width:100%;border-collapse:collapse;font-size:13px;} table.r th,table.r td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);vertical-align:top;}
 table.r th{font-size:11px;text-transform:uppercase;letter-spacing:.5px;color:var(--dim);}
 .sc{display:inline-block;min-width:26px;text-align:center;padding:2px 7px;border-radius:5px;font-weight:700;color:#EDF2F4;font-size:12px;}
 .crit{font-size:13px;margin:5px 0;padding-left:22px;position:relative;} .crit::before{content:'\2713';position:absolute;left:0;color:var(--accent);font-weight:700;}
 .alink{font-family:Consolas,monospace;font-size:11px;color:var(--blue);background:var(--soft);border:1px solid var(--line);border-radius:4px;padding:1px 6px;cursor:pointer;display:inline-block;margin:1px 0;}
 .alink:hover{background:var(--blue);color:#EDF2F4;}
 .docb{display:flex;align-items:center;gap:12px;padding:10px 12px;border:1px solid var(--line);border-radius:7px;margin-bottom:8px;background:var(--soft);}
 .docb.cv{cursor:pointer;} .docb.cv:hover{border-color:var(--blue);}
 .dtype{font-size:10px;font-weight:700;letter-spacing:.5px;text-transform:uppercase;color:var(--blue);background:var(--line);padding:5px 9px;border-radius:5px;min-width:64px;text-align:center;flex-shrink:0;}
 .dname{flex:1;font-size:13px;color:var(--ink);word-break:break-word;} .dview{font-size:11px;color:var(--blue);font-weight:600;white-space:nowrap;}
 .ovl{position:fixed;inset:0;background:rgba(11,17,28,.6);z-index:50;display:flex;align-items:center;justify-content:center;padding:20px;overflow:auto;}
 .ovl.hidden{display:none;}
 .modal{background:var(--panel);border-radius:10px;box-shadow:0 20px 60px rgba(0,0,0,.4);max-width:640px;width:100%;border-top:4px solid var(--blue);}
 .modal .mh{padding:18px 22px;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;align-items:flex-start;gap:12px;}
 .modal .mh .mid{font-family:Consolas,monospace;font-size:11px;color:var(--dim);} .modal .mh h3{margin:4px 0 0;font-size:17px;color:var(--blue);}
 .modal .x{border:none;background:var(--soft);border-radius:6px;cursor:pointer;font-size:16px;padding:4px 10px;color:var(--dim);} .modal .x:hover{background:var(--red);color:#EDF2F4;}
 .modal .mb{padding:18px 22px;} .kv{display:grid;grid-template-columns:120px 1fr;gap:6px 14px;font-size:13px;margin-bottom:14px;}
 .kv .k{color:var(--dim);text-transform:uppercase;font-size:10px;letter-spacing:.5px;padding-top:2px;}
 .modal .acc{font-size:13px;margin:4px 0;padding-left:20px;position:relative;} .modal .acc::before{content:'\2713';position:absolute;left:0;color:var(--accent);}
 .modal .note{font-size:11px;color:var(--dim);margin-top:14px;border-top:1px dashed var(--line);padding-top:10px;}
 #docModal{align-items:center;} .dvmodal{background:#fff;border-radius:10px;box-shadow:0 20px 60px rgba(0,0,0,.5);width:min(1100px,96vw);height:92vh;display:flex;flex-direction:column;overflow:hidden;}
 .dvh{display:flex;justify-content:space-between;align-items:center;padding:12px 18px;border-bottom:1px solid var(--line);} .dvh span{font-size:13px;font-weight:600;color:var(--blue);}
 #dvframe{flex:1;border:none;width:100%;}
 footer{text-align:center;padding:30px;font-size:12px;color:rgba(237,242,244,.5);}
</style></head><body>
<header class="top"><div class="inner">
 <div><h1><b>Astrid</b><span class="d">.</span> projects</h1><div class="sub">project-overview portal</div></div>
 <div class="meta">__DATE__<br><a href="dashboard.html" style="color:var(--accent);">&rarr; action dashboard</a></div>
</div></header>
<main>
 <section class="view" id="v-grid"><h2 class="stitle"><span id="cnt"></span></h2><div class="grid" id="grid"></div></section>
 <section class="view hidden" id="v-detail"></section>
</main>
<div class="ovl hidden" id="cardModal" onclick="if(event.target===this)closeCard()"><div class="modal" id="cardBody"></div></div>
<div class="ovl hidden" id="docModal" onclick="if(event.target===this)closeDoc()"><div class="dvmodal"><div class="dvh"><span id="dvtitle"></span><button class="x" onclick="closeDoc()">&times;</button></div><iframe id="dvframe" src="about:blank"></iframe></div></div>
<footer>Astrid portal &middot; generated __DATE__</footer>
<script>
const PROJECTS=__PROJECTS__, CARDS=__CARDS__, ALLCARDS=__ALLCARDS__, RISKS=__RISKS__, DELIVERABLES=__DELIVERABLES__, DETAILS=__DETAILS__, DOCS=__DOCS__;
const PHASES=['Initiation','Execution','Go-live','Aftercare','Done'];
function esc(s){return String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
function arr(x){return Array.isArray(x)?x:(x==null?[]:[x]);}
function pid(c){return c.project?c.project.replace('/','-'):null;}
function phaseOf(p){return ({initiation:1,execution:2,golive:3,aftercare:4,done:5,paused:2,cancelled:1})[p.status]||1;}
function hcolor(h){return h==='green'?'var(--accent)':h==='yellow'?'var(--warn)':h==='red'?'var(--red)':'#9aa3ad';}
function cardsFor(id){return CARDS.filter(c=>pid(c)===id);}
function risksFor(id){return RISKS.filter(r=>r.project_id===id);}
function delivFor(id){return DELIVERABLES.filter(d=>d.project_id===id);}
function classify(c){if(c.urgent||c.late)return 'u';if(['WAIT','PLAN','BLOCKED'].includes(c.status))return 'w';return 'n';}
function findCard(id){return ALLCARDS.find(c=>c.id===id)||CARDS.find(c=>c.id===id)||null;}
function actionLink(id){return `<span class="alink" onclick="event.stopPropagation();openCard('${id}')">${esc(id)}</span>`;}
function scoreColor(s){return s>=15?'var(--red)':s>=8?'var(--warn)':'var(--accent)';}

function tile(p){const ac=cardsFor(p.id).length,rk=risksFor(p.id).length;
 return `<div class="pcard" onclick="showProject('${p.id}')"><h2>${esc(p.title)}</h2><div class="cust">${esc(p.customer||'')}</div>
  <div class="badges"><span class="badge"><span class="hdot" style="background:${hcolor(p.health_level)}"></span>${esc(p.status)}</span>${p.classification?`<span class="badge">${esc(p.classification)}</span>`:''}</div>
  <div class="stats"><div class="stat"><div class="n">${ac}</div><div class="l">actions</div></div><div class="stat r"><div class="n">${rk}</div><div class="l">risks</div></div><div class="stat"><div class="n">P${phaseOf(p)}</div><div class="l">phase</div></div></div></div>`;}
function renderGrid(){const ps=PROJECTS.filter(p=>p.status!=='cancelled').sort((a,b)=>(a.status==='done')-(b.status==='done'));
 document.getElementById('grid').innerHTML=ps.map(tile).join('')||'<p style="color:#EDF2F4;opacity:.6">No projects.</p>';
 document.getElementById('cnt').textContent=ps.length+' projects';}
function fasenSvg(cur){let out='';const col=i=>i+1<cur?'#24252F':i+1===cur?'#CC3333':'#8D99AE';
 for(let i=0;i<5;i++){const L=i*200;const pts=`${L},6 ${L+170},6 ${L+200},34 ${L+170},62 ${L},62 ${L+30},34`;
  out+=`<polygon points="${pts}" fill="${col(i)}" stroke="#EDF2F4" stroke-width="2"/><text x="${L+40}" y="30" fill="${i+1>cur?'#0c2a4d':'#EDF2F4'}" style="font:700 10px Segoe UI">PHASE ${i+1}</text><text x="${L+40}" y="46" fill="${i+1>cur?'#0c2a4d':'#EDF2F4'}" style="font:600 11px Segoe UI">${PHASES[i]}</text>`;}
 return `<svg viewBox="0 0 1000 70" preserveAspectRatio="xMidYMid meet">${out}</svg>`;}
function acCard(c){const fl=(c.urgent?'&#128293;':'')+(c.late?'&#9888;':'')+(c.stale?'&#128164;':'');
 return `<div class="ac" onclick="openCard('${c.id}')"><div class="id">${c.id}</div><div class="t">${esc(c.title)}</div><div class="m">${c.deadline?`<span>${c.deadline}</span>`:''}<span class="st">${c.status}</span>${fl?`<span>${fl}</span>`:''}</div></div>`;}
function relRow(label,ids){const a=arr(ids).filter(Boolean);return a.length?`<div class="k" style="margin-top:8px">${label}</div><div>${a.map(actionLink).join(' ')}</div>`:'';}
function openCard(id){const c=findCard(id);const b=document.getElementById('cardBody');
 if(!c){b.innerHTML=`<div class="mh"><div><div class="mid">${esc(id)}</div><h3>Card not in index</h3></div><button class="x" onclick="closeCard()">&times;</button></div><div class="mb" style="color:var(--dim)">This card is not in the index.</div>`;}
 else{const fl=(c.urgent?'&#128293; urgent ':'')+(c.late?'&#9888; late ':'')+(c.stale?'&#128164; stale':'');
  const acc=arr(c.acceptance_criteria).filter(Boolean).map(a=>`<div class="acc">${esc(a)}</div>`).join('');
  b.innerHTML=`<div class="mh"><div><div class="mid">${esc(c.id)}</div><h3>${esc(c.title)}</h3></div><button class="x" onclick="closeCard()">&times;</button></div>
   <div class="mb"><div class="kv">
    <div class="k">Status</div><div><span style="background:rgba(0,0,0,.06);padding:2px 8px;border-radius:4px;text-transform:uppercase;font-size:11px">${esc(c.status)}</span> ${fl}</div>
    ${c.type?`<div class="k">Type</div><div>${esc(c.type)}</div>`:''}${c.priority?`<div class="k">Priority</div><div>${esc(c.priority)}</div>`:''}
    ${(c.deadline||c.deadline_text)?`<div class="k">Deadline</div><div>${esc(c.deadline||'')} <span style="color:var(--dim)">${esc(c.deadline_text||'')}</span></div>`:''}
    ${c.assignee?`<div class="k">Assignee</div><div>${esc(c.assignee)}</div>`:''}${c.project?`<div class="k">Project</div><div>${esc(c.project)}</div>`:''}
   </div>${relRow('Depends on',c.depends_on)}${relRow('Blocks',c.blocks)}${relRow('Related',c.relates_to)}
   ${acc?`<div class="k" style="margin:12px 0 4px">Acceptance criteria</div>${acc}`:''}
   <div class="note">Read-only view from the index. Full card lives at: <code>${esc(c.file||'')}</code></div></div>`;}
 document.getElementById('cardModal').classList.remove('hidden');}
function closeCard(){document.getElementById('cardModal').classList.add('hidden');}
function emptyDoc(){return '<div style="color:var(--dim);font-size:13px">-</div>';}
function docBlock(d){const can=!!d.prev;const click=can?`onclick="openDoc('${esc(d.prev)}','${esc(d.file)}')"`:'';
 const act=can?'<span class="dview">&#128065; view</span>':`<a class="dview" href="${esc(d.rel)}" target="_blank">download</a>`;
 return `<div class="docb${can?' cv':''}" ${click}><div class="dtype">${esc(d.ext)}</div><div class="dname">${esc(d.file)}</div>${act}</div>`;}
function openDoc(url,title){document.getElementById('dvtitle').textContent=title;document.getElementById('dvframe').src=url;document.getElementById('docModal').classList.remove('hidden');}
function closeDoc(){document.getElementById('docModal').classList.add('hidden');document.getElementById('dvframe').src='about:blank';}

function showProject(id){const p=PROJECTS.find(x=>x.id===id);const d=DETAILS[id]||{};const cur=phaseOf(p);
 const my=cardsFor(id),bk={u:[],n:[],w:[]};my.forEach(c=>bk[classify(c)].push(c));
 const meta=[p.customer,p.classification,(d.timeline&&d.timeline.start_date)?('start '+d.timeline.start_date):''].filter(Boolean).map(m=>`<span>${esc(m)}</span>`).join('');
 const acT=`<div class="cols"><div class="col u"><h3>Urgent / late (${bk.u.length})</h3>${bk.u.map(acCard).join('')||emptyDoc()}</div>
   <div class="col n"><h3>In progress (${bk.n.length})</h3>${bk.n.map(acCard).join('')||emptyDoc()}</div>
   <div class="col w"><h3>Waiting / planned (${bk.w.length})</h3>${bk.w.map(acCard).join('')||emptyDoc()}</div></div>`;
 const rks=risksFor(id).sort((a,b)=>(b.score||0)-(a.score||0));
 const riT=rks.length?`<div class="panelw"><table class="r"><tr><th>Risk</th><th>Response</th><th>P&times;I</th><th>Status</th><th>Mitigating actions</th></tr>
   ${rks.map(r=>`<tr><td>${esc(r.title)}</td><td>${esc(r.response||'')}</td><td>${r.score?`<span class="sc" style="background:${scoreColor(r.score)}">${r.score}</span> <span style="color:var(--dim);font-size:11px">${esc(r.probability||'')}/${esc(r.impact||'')}</span>`:'<span style="color:var(--dim);font-size:11px;font-style:italic">unscored</span>'}</td><td>${esc(r.status||'')}</td><td>${arr(r.mitigation_action_cards).map(actionLink).join(' ')||'<span style="color:var(--dim)">-</span>'}</td></tr>`).join('')}</table></div>`:'<div class="panelw" style="color:var(--dim)">No risk-cards.</div>';
 const dvs=delivFor(id);
 const dvrows=dvs.map(x=>`<tr><td>${esc(x.title)}</td><td><span class="badge">${esc(x.status)}</span></td><td style="font-size:11px;color:var(--dim)">${arr(x.acceptance_criteria).map(esc).join('<br>')}</td><td>${arr(x.action_cards).map(actionLink).join(' ')||'<span style="color:var(--dim)">-</span>'}</td></tr>`).join('');
 const crit=arr(d.success_criteria).map(c=>`<div class="crit">${esc(c)}</div>`).join('');
 const dlT=`<div class="panelw"><h3 style="color:var(--blue);font-size:13px;text-transform:uppercase;letter-spacing:1px">Deliverables</h3>${dvs.length?`<table class="r"><tr><th>Deliverable</th><th>Status</th><th>Acceptance criteria</th><th>Actions</th></tr>${dvrows}</table>`:'<div style="color:var(--dim)">No deliverable-cards.</div>'}${crit?`<h3 style="color:var(--blue);font-size:13px;text-transform:uppercase;letter-spacing:1px;margin-top:18px">Success criteria</h3>${crit}`:''}</div>`;
 const dl=arr(DOCS[id]).map(docBlock).join('');
 const refs=d.references?Object.entries(d.references).filter(([k,v])=>v&&k!=='extra').map(([k,v])=>`<div style="font-size:13px;margin:4px 0"><b>${esc(k)}:</b> ${esc(v)}</div>`).join(''):'';
 const docT=`<div class="panelw"><h3 style="color:var(--blue);font-size:13px;text-transform:uppercase;letter-spacing:1px">Documents</h3>${dl||'<div style="color:var(--dim)">No documents/ folder.</div>'}${refs?`<h3 style="color:var(--blue);font-size:13px;text-transform:uppercase;letter-spacing:1px;margin-top:16px">References</h3>${refs}`:''}</div>`;
 const tabs={Actions:acT,Risks:riT,Deliverables:dlT,Documents:docT};
 const v=document.getElementById('v-detail');
 v.innerHTML=`<button class="back" onclick="showGrid()">&larr; Back to projects</button>
  <div class="phead"><div class="bar"><h2>${esc(p.title)}</h2><div class="cust">${esc(p.customer||'')}</div><div class="pmeta">${meta}</div></div>
   <div class="fasen">${fasenSvg(cur)}</div>
   <div class="tabs" id="tabs">${Object.keys(tabs).map((k,i)=>`<div class="tab${i===0?' active':''}" onclick="selTab(${i})">${esc(k)}</div>`).join('')}</div></div>
  <div id="tabbody">${tabs.Actions}</div>`;
 window._tabs=tabs; window._tabKeys=Object.keys(tabs);
 document.getElementById('v-grid').classList.add('hidden');v.classList.remove('hidden');window.scrollTo(0,0);}
function selTab(i){const k=window._tabKeys[i];document.querySelectorAll('#tabs .tab').forEach((t,j)=>t.classList.toggle('active',j===i));document.getElementById('tabbody').innerHTML=window._tabs[k];}
function showGrid(){document.getElementById('v-detail').classList.add('hidden');document.getElementById('v-grid').classList.remove('hidden');}
renderGrid();
document.addEventListener('keydown',e=>{if(e.key==='Escape'){const dm=document.getElementById('docModal'),m=document.getElementById('cardModal');if(dm&&!dm.classList.contains('hidden'))closeDoc();else if(m&&!m.classList.contains('hidden'))closeCard();else showGrid();}});
</script></body></html>
'@

$html = $tpl.Replace('__PROJECTS__',$projectsJson).Replace('__CARDS__',$cardsJson).Replace('__ALLCARDS__',$allCardsJson).Replace('__RISKS__',$risksJson).Replace('__DELIVERABLES__',$delivJson).Replace('__DETAILS__',$detailsJson).Replace('__DOCS__',$docsJson).Replace('__DATE__',$dateStr)
[System.IO.File]::WriteAllText($htmlPath,$html,[System.Text.UTF8Encoding]::new($false))
Write-Host ("Done: {0} ({1} KB)" -f $htmlPath,[int]((Get-Item $htmlPath).Length/1024)) -ForegroundColor Green
if ($Open) { if ($IsWindows -or $env:OS) { Start-Process $htmlPath } else { Write-Host "Open $htmlPath" } }
