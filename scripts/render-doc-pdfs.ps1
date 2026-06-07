# render-doc-pdfs.ps1
# Optional helper (Windows + Microsoft Office): renders Word/Excel files in each project's
# documents/ folder to a sibling PDF (<name>.pdf), so the project portal can show them
# inline (an iframe can render PDF, but not docx/xlsx). PDF/HTML/PNG/Markdown are already
# shown inline by the portal and need no rendering.
#
# Change-detection: only (re)renders when the PDF is missing or older than the source.
# Cross-platform note: this uses Office COM and therefore runs on Windows only. On other
# platforms, keep documents as PDF/HTML/Markdown (rendered inline without this helper).
#
# Usage:  pwsh -File scripts/render-doc-pdfs.ps1 -Root <workspace> [-Force]
[CmdletBinding()]
param(
  [string]$Root = (Get-Location).Path,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
if (-not ($IsWindows -or $env:OS)) { Write-Host 'render-doc-pdfs requires Windows + Microsoft Office; skipping.'; return }
$rootAbs = (Resolve-Path $Root).Path

function Get-Todo($ext) {
  Get-ChildItem -Path $rootAbs -Recurse -Filter ('*' + $ext) -File |
    Where-Object { $_.DirectoryName -match '[\\/]documents$' -and $_.Name -notlike '_*' -and $_.Name -notlike '~$*' } |
    ForEach-Object {
      $pdf = [System.IO.Path]::ChangeExtension($_.FullName, '.pdf')
      if ($Force -or -not (Test-Path $pdf) -or (Get-Item $pdf).LastWriteTime -lt $_.LastWriteTime) {
        [pscustomobject]@{ src = $_.FullName; pdf = $pdf }
      }
    }
}
$wordTodo = @(Get-Todo '.docx')
$xlTodo = @(Get-Todo '.xlsx') + @(Get-Todo '.xlsb')
$done = 0

if ($wordTodo.Count -gt 0) {
  $word = New-Object -ComObject Word.Application; $word.Visible = $false; $word.DisplayAlerts = 0
  try {
    foreach ($t in $wordTodo) {
      $doc = $word.Documents.Open($t.src, $false, $true)
      if (Test-Path $t.pdf) { Remove-Item $t.pdf -Force }
      $doc.SaveAs([ref]$t.pdf, [ref]17)   # 17 = wdFormatPDF
      $doc.Close($false); Write-Host ('  PDF (Word) : ' + (Split-Path $t.pdf -Leaf)); $done++
    }
  } finally { try { $word.Quit() } catch {}; [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null; [GC]::Collect() }
}
if ($xlTodo.Count -gt 0) {
  $excel = New-Object -ComObject Excel.Application; $excel.Visible = $false; $excel.DisplayAlerts = $false
  try {
    foreach ($t in $xlTodo) {
      try {
        $wb = $excel.Workbooks.Open($t.src, 0, $true)
        if (Test-Path $t.pdf) { Remove-Item $t.pdf -Force }
        $wb.ExportAsFixedFormat(0, $t.pdf)   # 0 = xlTypePDF (whole workbook)
        $wb.Close($false); Write-Host ('  PDF (Excel): ' + (Split-Path $t.pdf -Leaf)); $done++
      } catch { Write-Warning ('Excel export failed for ' + (Split-Path $t.src -Leaf) + ' : ' + $_.Exception.Message) }
    }
  } finally { try { $excel.Quit() } catch {}; [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null; [GC]::Collect() }
}
if ($done -eq 0) { Write-Host 'PDF renditions up to date.' } else { Write-Host ('Done: ' + $done + ' PDF(s) rendered.') }
