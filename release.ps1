<#
  release.ps1 - one-command release.
  Rebuilds the portable skills from the vault, bumps the plugin version, commits, and pushes.
  Run this AFTER you have updated the skills in your Obsidian vault.

  Usage:
    powershell -ExecutionPolicy Bypass -File release.ps1                          # patch bump (0.1.0 -> 0.1.1)
    powershell -ExecutionPolicy Bypass -File release.ps1 -Bump minor -Message "..."   # 0.1.0 -> 0.2.0
    powershell -ExecutionPolicy Bypass -File release.ps1 -Version 1.0.0            # set an explicit version
    powershell -ExecutionPolicy Bypass -File release.ps1 -DryRun                   # preview only: no writes/commit/push
#>
param(
  [string]$Message = 'update skills',
  [ValidateSet('patch','minor','major')][string]$Bump = 'patch',
  [string]$Version = '',
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)   # no BOM
$pluginJson = Join-Path $root 'plugins\dsm-soil\.claude-plugin\plugin.json'

# 1) rebuild the portable skills from the vault (source of truth)
Write-Host "==> build (compile skills from the vault)"
& (Join-Path $root 'build.ps1')

# 2) anything to release?
$changed = git -C $root status --porcelain
if (-not $changed) { Write-Host "Nothing changed since last release. Done."; exit 0 }

# 3) compute the next version
$txt = [System.IO.File]::ReadAllText($pluginJson)
$cur = ([regex]::Match($txt, '"version"\s*:\s*"([^"]+)"')).Groups[1].Value
if ($Version) {
  $new = $Version
} else {
  $p = $cur.Split('.'); $maj=[int]$p[0]; $min=[int]$p[1]; $pat=[int]$p[2]
  switch ($Bump) { 'major' { $maj++; $min=0; $pat=0 }; 'minor' { $min++; $pat=0 }; 'patch' { $pat++ } }
  $new = "$maj.$min.$pat"
}

Write-Host "==> version $cur -> $new"
Write-Host "==> changes:"
$changed | ForEach-Object { Write-Host "     $_" }

if ($DryRun) { Write-Host "DryRun: nothing written, no commit, no push."; exit 0 }

# 4) write the new version, commit, push
$txt = [regex]::Replace($txt, '("version"\s*:\s*")[^"]+(")', "`${1}$new`${2}")
[System.IO.File]::WriteAllText($pluginJson, $txt, $utf8)
git -C $root add -A | Out-Null
git -C $root commit -m "$Message (v$new)" | Out-Null
git -C $root push
Write-Host "==> released v$new and pushed. Upgrade installed copies from the /plugin menu."
