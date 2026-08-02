<#
  build.ps1 — compile the forged skills from the Obsidian vault into self-contained,
  portable Claude Code skills inside this plugin.

  What it does:
    - reads each SKILL.md from the vault (the SOURCE OF TRUTH)
    - flattens Obsidian [[wiki links]] to plain readable text (they don't resolve
      outside the vault), so each skill stands alone in any project/folder
    - writes the result to plugins/dsm-soil/skills/<name>/SKILL.md

  Re-run this whenever you edit the skills in the vault, then commit + push.
  Usage:  pwsh -File build.ps1     (or)     powershell -ExecutionPolicy Bypass -File build.ps1
#>
$ErrorActionPreference = 'Stop'

# Vault location (source of truth). Override with the DSM_VAULT env var; otherwise
# defaults to a sibling 'Soil_skill/skills-forge' next to this repo.
$vault = if ($env:DSM_VAULT) { $env:DSM_VAULT } else { Join-Path $PSScriptRoot '..\Soil_skill\skills-forge' }

$out = Join-Path $PSScriptRoot 'plugins\dsm-soil\skills'
$skills = @(
  'soil-map-validation',
  'ml-for-soil-prediction',
  'digital-soil-mapping-workflow',
  'soc-stock-mrv',
  'rothc-temporal-modelling',
  'hybrid-process-ml-soc',
  'soil-fertility-mapping',
  'spatial-prediction-uncertainty',
  'soil-sampling-design',
  'spatial-statistics-areal'
)
$utf8 = [System.Text.UTF8Encoding]::new($false)   # no BOM
$note = "`n`n---`n_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._`n"

function Flatten([string]$t) {
  # [[target|alias]]  -> alias
  $t = [regex]::Replace($t, '\[\[[^\]\|]+\|([^\]]+)\]\]', '$1')
  # [[a/b/c]]         -> c   (last path segment, humanised)
  $t = [regex]::Replace($t, '\[\[([^\]\|]+)\]\]', { param($m) ($m.Groups[1].Value -split '/')[-1] })
  return $t
}

$n = 0
foreach ($s in $skills) {
  $src = Join-Path $vault "$s\SKILL.md"
  if (-not (Test-Path $src)) { Write-Warning "MISSING: $src"; continue }
  $dstDir = Join-Path $out $s
  New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
  $body = (Flatten ([System.IO.File]::ReadAllText($src))) + $note
  [System.IO.File]::WriteAllText((Join-Path $dstDir 'SKILL.md'), $body, $utf8)
  Write-Host "compiled: $s"
  $n++
}
Write-Host "done - $n skill(s) -> $out"
