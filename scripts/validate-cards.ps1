# validate-cards.ps1
# Validates every card in a workspace against its JSON schema.
# Full validation uses ajv-cli via npx when Node.js is available; otherwise it
# falls back to dependency-free checks derived FROM each schema (schema_version
# const, required fields present, id pattern) — no hardcoded field lists.
#
# Card type is decided by filename / location:
#   project.json            -> project-card-v1
#   CONTACT-*.json          -> contact-card-v1
#   MTG-*.json              -> meeting-card-v1
#   RISK-* / DEC-* / ISS-* / MS-* / DLV-*  -> the matching schema
#   anything else in cards/ -> action-card-v2
#
# Usage:  pwsh -File scripts/validate-cards.ps1 -Root <path-to-workspace>

[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path,
    [string]$SchemaDir = (Join-Path $PSScriptRoot '..\reference\schemas')
)

$ErrorActionPreference = 'Stop'
$rootAbs   = (Resolve-Path $Root).Path
$schemaAbs = (Resolve-Path $SchemaDir).Path

# Type table: ordered — first match wins. Each entry maps a filename test to a schema.
$types = @(
    @{ name = 'project-card';     schema = 'project-card-v1.schema.json';     test = { param($f) $f.Name -eq 'project.json' } },
    @{ name = 'contact-card';     schema = 'contact-card-v1.schema.json';     test = { param($f) $f.Name -like 'CONTACT-*' } },
    @{ name = 'meeting-card';     schema = 'meeting-card-v1.schema.json';     test = { param($f) $f.Name -like 'MTG-*' } },
    @{ name = 'risk-card';        schema = 'risk-card-v1.schema.json';        test = { param($f) $f.Name -like 'RISK-*' } },
    @{ name = 'decision-card';    schema = 'decision-card-v1.schema.json';    test = { param($f) $f.Name -like 'DEC-*' } },
    @{ name = 'issue-card';       schema = 'issue-card-v1.schema.json';       test = { param($f) $f.Name -like 'ISS-*' } },
    @{ name = 'milestone-card';   schema = 'milestone-card-v1.schema.json';   test = { param($f) $f.Name -like 'MS-*' } },
    @{ name = 'deliverable-card'; schema = 'deliverable-card-v1.schema.json'; test = { param($f) $f.Name -like 'DLV-*' } },
    @{ name = 'action-card';      schema = 'action-card-v2.schema.json';      test = { param($f) $f.FullName -match '[\\/]cards[\\/]' } }
)

# Pre-load schema metadata for the light checks.
foreach ($t in $types) {
    $sp = Join-Path $schemaAbs $t.schema
    if (-not (Test-Path $sp)) { Write-Error "Schema not found: $sp"; exit 1 }
    $t.schemaPath = $sp
    $sch = Get-Content $sp -Raw -Encoding utf8 | ConvertFrom-Json
    $t.required   = @($sch.required)
    $t.idPattern  = if ($sch.properties.id) { $sch.properties.id.pattern } else { $null }
    $t.versionConst = if ($sch.properties.schema_version) { $sch.properties.schema_version.const } else { $null }
}

function Get-CardType($file) {
    foreach ($t in $types) { if (& $t.test $file) { return $t } }
    return $null
}

$ajvAvailable = $false
try { $null = & npx --yes ajv-cli --help 2>$null; $ajvAvailable = ($LASTEXITCODE -eq 0) } catch { }

$errors = @()
$counts = @{}

Get-ChildItem -Path $rootAbs -Recurse -Filter '*.json' -File |
    Where-Object {
        $_.FullName -notmatch '[\\/]_index[\\/]' -and
        $_.Name -notlike '_*'
    } |
    ForEach-Object {
        $file = $_
        $t = Get-CardType $file
        if (-not $t) { return }   # not a card we validate (e.g. a stray json)
        $relPath = $file.FullName.Replace($rootAbs + [IO.Path]::DirectorySeparatorChar, '')
        $counts[$t.name] = ($counts[$t.name] + 1)

        if ($ajvAvailable) {
            $output = & npx --yes ajv-cli validate --spec=draft2020 -s $t.schemaPath -d $file.FullName 2>&1
            if ($LASTEXITCODE -ne 0) { $errors += "[$($t.name)] $relPath : $output" }
            return
        }

        # Light, schema-derived checks
        try { $card = Get-Content $file.FullName -Raw -Encoding utf8 | ConvertFrom-Json }
        catch { $errors += "[$($t.name)] $relPath : JSON parse error — $_"; return }

        foreach ($f in $t.required) {
            if (-not $card.PSObject.Properties[$f]) { $errors += "[$($t.name)] $relPath : missing required field '$f'" }
        }
        if ($null -ne $t.versionConst -and $card.schema_version -ne $t.versionConst) {
            $errors += "[$($t.name)] $relPath : schema_version must be $($t.versionConst), was '$($card.schema_version)'"
        }
        if ($t.idPattern -and $card.id -and $card.id -notmatch $t.idPattern) {
            $errors += "[$($t.name)] $relPath : id '$($card.id)' does not match $($t.idPattern)"
        }
        # Filename should match id for typed cards (project.json is the exception)
        if ($t.name -ne 'project-card' -and $card.id -and ($file.BaseName -ne $card.id)) {
            $errors += "[$($t.name)] $relPath : filename ($($file.BaseName)) differs from id ($($card.id))"
        }
    }

if ($ajvAvailable) { Write-Host "Full schema validation via ajv-cli." -ForegroundColor Green }
else {
    Write-Host "ajv-cli not available — light schema-derived checks applied." -ForegroundColor Yellow
    Write-Host "For full JSON Schema validation: 'npm i -g ajv-cli' or 'npx ajv-cli'." -ForegroundColor Yellow
}

$total = ($counts.Values | Measure-Object -Sum).Sum
Write-Host "$total cards validated:"
foreach ($k in ($counts.Keys | Sort-Object)) { Write-Host ("  {0,-16} {1}" -f $k, $counts[$k]) }

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "$($errors.Count) error(s):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host ""
Write-Host "All cards valid." -ForegroundColor Green
