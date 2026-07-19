<#
  install.ps1 — manual install WITHOUT the plugin system.
  Copies the skills into your personal Claude Code skills folder (~/.claude/skills),
  making them available in every project on this machine.

  Prefer the plugin+marketplace flow (see README) for versioning/uninstall.
  Usage:  powershell -ExecutionPolicy Bypass -File install.ps1
#>
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'plugins\dsm-soil\skills'
$dst = Join-Path $HOME '.claude\skills'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
Write-Host "Installed DSM skills to $dst"
