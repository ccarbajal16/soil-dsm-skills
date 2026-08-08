<#
  release.ps1 - one-command release.
  Rebuilds the portable skills from the vault, checks the manifests are in sync with the
  skill roster, bumps the plugin version, commits, pushes, tags, and creates the GitHub release.
  Run this AFTER you have updated the skills in your Obsidian vault.

  Usage:
    powershell -ExecutionPolicy Bypass -File release.ps1                              # patch bump (0.1.0 -> 0.1.1)
    powershell -ExecutionPolicy Bypass -File release.ps1 -Bump minor -Message "..."   # 0.1.0 -> 0.2.0
    powershell -ExecutionPolicy Bypass -File release.ps1 -Version 1.0.0               # set an explicit version
    powershell -ExecutionPolicy Bypass -File release.ps1 -DryRun                      # preview only: no writes/commit/push/tag
    powershell -ExecutionPolicy Bypass -File release.ps1 -NotesFile notes.md          # release notes from a file
    powershell -ExecutionPolicy Bypass -File release.ps1 -SkipTag                     # commit+push only, no tag/release
    powershell -ExecutionPolicy Bypass -File release.ps1 -SkipRelease                 # tag, but no GitHub release
    powershell -ExecutionPolicy Bypass -File release.ps1 -Force                       # override the manifest-sync guard
#>
param(
  [string]$Message = 'update skills',
  [ValidateSet('patch','minor','major')][string]$Bump = 'patch',
  [string]$Version = '',
  [string]$NotesFile = '',
  [switch]$SkipTag,
  [switch]$SkipRelease,
  [switch]$Force,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)   # no BOM
$pluginJson      = Join-Path $root 'plugins\dsm-soil\.claude-plugin\plugin.json'
$marketplaceJson = Join-Path $root '.claude-plugin\marketplace.json'
$buildPs1        = Join-Path $root 'build.ps1'
$skillsDir       = Join-Path $root 'plugins\dsm-soil\skills'

# 1) rebuild the portable skills from the vault (source of truth)
Write-Host "==> build (compile skills from the vault)"
& $buildPs1

# 2) manifest-sync guard --------------------------------------------------------------
#    The v0.4.1 bug: a skill was added to the roster but marketplace.json still described
#    the old one. Manifests are the only thing users see before installing, so a stale
#    description reaches everyone. This makes that failure loud instead of silent.
Write-Host "==> guard (manifests vs skill roster)"

# roster as declared in build.ps1
$buildTxt   = [System.IO.File]::ReadAllText($buildPs1)
$rosterBlock = ([regex]::Match($buildTxt, '(?s)\$skills\s*=\s*@\((.*?)\)')).Groups[1].Value
$roster = [regex]::Matches($rosterBlock, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
$built  = Get-ChildItem -Path $skillsDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
            ForEach-Object { $_.Name }

$problems = @()

# 2a) every declared skill actually compiled, and nothing stale is left behind
$missing = $roster | Where-Object { $built -notcontains $_ }
$extra   = $built  | Where-Object { $roster -notcontains $_ }
if ($missing) { $problems += "declared in build.ps1 but not compiled: $($missing -join ', ')" }
if ($extra)   { $problems += "compiled but not in the build.ps1 roster (stale?): $($extra -join ', ')" }

$count = $roster.Count

# 2b) the "<N> skills" claim in each manifest matches the real count
foreach ($m in @($marketplaceJson, $pluginJson)) {
  $t = [System.IO.File]::ReadAllText($m)
  foreach ($hit in [regex]::Matches($t, '(\d+)\s+(?:soil-science\s+)?skills')) {
    $claimed = [int]$hit.Groups[1].Value
    if ($claimed -ne $count) {
      $problems += "$(Split-Path $m -Leaf) says '$($hit.Value)' but the roster has $count"
    }
  }
}

# 2c) if the ROSTER changed since the last tag, the manifests must have changed too.
#     Roster change = a skill was added, removed or renamed. Editing the CONTENT of an
#     existing skill is not a roster change and must not trip this check.
$lastTag = (git -C $root describe --tags --abbrev=0 2>$null)
if ($LASTEXITCODE -eq 0 -and $lastTag) {
  $prevRoster = @(git -C $root ls-tree -d --name-only "${lastTag}:plugins/dsm-soil/skills" 2>$null)
  $added   = $roster     | Where-Object { $prevRoster -notcontains $_ }
  $removed = $prevRoster | Where-Object { $roster     -notcontains $_ }

  if ($added -or $removed) {
    $what = @()
    if ($added)   { $what += "added: $($added -join ', ')" }
    if ($removed) { $what += "removed: $($removed -join ', ')" }
    $what = $what -join '; '

    $touched = git -C $root diff --name-only "$lastTag..HEAD" -- . 2>$null
    $pending = git -C $root status --porcelain | ForEach-Object { ($_ -replace '^.{3}','').Trim('"') }
    $allChanged = @($touched) + @($pending)

    if (-not ($allChanged | Where-Object { $_ -eq '.claude-plugin/marketplace.json' })) {
      $problems += "roster changed since $lastTag ($what) but marketplace.json was not updated"
    }
    if (-not ($allChanged | Where-Object { $_ -like '*dsm-soil/.claude-plugin/plugin.json' })) {
      $problems += "roster changed since $lastTag ($what) but plugin.json was not updated"
    }
  }
}

if ($problems) {
  Write-Host ""
  Write-Host "MANIFEST GUARD FAILED:" -ForegroundColor Red
  $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  Write-Host ""
  if (-not $Force) {
    Write-Host "Fix the manifests, or re-run with -Force to release anyway." -ForegroundColor Yellow
    exit 1
  }
  Write-Host "-Force given: continuing despite the above." -ForegroundColor Yellow
} else {
  Write-Host "    ok - $count skills, manifests in sync"
}

# 3) anything to release?
$changed = git -C $root status --porcelain
if (-not $changed) { Write-Host "Nothing changed since last release. Done."; exit 0 }

# 4) compute the next version
$txt = [System.IO.File]::ReadAllText($pluginJson)
$cur = ([regex]::Match($txt, '"version"\s*:\s*"([^"]+)"')).Groups[1].Value
if ($Version) {
  $new = $Version
} else {
  $p = $cur.Split('.'); $maj=[int]$p[0]; $min=[int]$p[1]; $pat=[int]$p[2]
  switch ($Bump) { 'major' { $maj++; $min=0; $pat=0 }; 'minor' { $min++; $pat=0 }; 'patch' { $pat++ } }
  $new = "$maj.$min.$pat"
}
$tag = "v$new"

# refuse to reuse a tag
$existing = git -C $root tag --list $tag
if ($existing -and -not $SkipTag) {
  Write-Host "Tag $tag already exists. Pick another version, or pass -SkipTag." -ForegroundColor Red
  exit 1
}

Write-Host "==> version $cur -> $new"
Write-Host "==> changes:"
$changed | ForEach-Object { Write-Host "     $_" }

if ($DryRun) {
  Write-Host "DryRun: would commit, push, tag $tag$(if(-not $SkipRelease){' and create the GitHub release'})."
  Write-Host "DryRun: nothing written, no commit, no push, no tag."
  exit 0
}

# 5) write the new version, commit, push
$txt = [regex]::Replace($txt, '("version"\s*:\s*")[^"]+(")', "`${1}$new`${2}")
[System.IO.File]::WriteAllText($pluginJson, $txt, $utf8)
git -C $root add -A | Out-Null
git -C $root commit -m "$Message (v$new)" | Out-Null
git -C $root push
Write-Host "==> pushed commit"

if ($SkipTag) {
  Write-Host "==> released v$new (no tag, -SkipTag). Upgrade installed copies from the /plugin menu."
  exit 0
}

# 6) annotated tag on the release commit, then push it
git -C $root tag -a $tag -m "$tag - $Message"
git -C $root push origin $tag
Write-Host "==> tagged $tag and pushed"

# 7) GitHub release
if ($SkipRelease) {
  Write-Host "==> skipped GitHub release (-SkipRelease)."
} elseif (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "==> gh CLI not found; tag pushed but no GitHub release created." -ForegroundColor Yellow
  Write-Host "    create it later with: gh release create $tag --generate-notes"
} else {
  if ($NotesFile -and (Test-Path $NotesFile)) {
    gh release create $tag --title "$tag" --notes-file $NotesFile
  } else {
    gh release create $tag --title "$tag" --generate-notes
  }
  Write-Host "==> GitHub release $tag created"
}

Write-Host "==> released v$new. Upgrade installed copies from the /plugin menu."
