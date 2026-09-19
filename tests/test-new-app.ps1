<#
.SYNOPSIS
Checks new-app.ps1 against the ways it has been wrong before. No test framework:
run it, read the lines, exit code 0 means every case held.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tests\test-new-app.ps1
#>
param(
    [string] $WorkRoot = (Join-Path $env:TEMP 'kit-tests')
)
$ErrorActionPreference = 'Stop'

$kit = Split-Path -Parent $PSScriptRoot
$script = Join-Path $kit 'new-app.ps1'
$failures = 0

function Check([string] $name, [bool] $ok) {
    if ($ok) { Write-Output "  ok    $name" } else { Write-Output "  FAIL  $name"; $script:failures++ }
}
function Has([string] $path, [string] $pattern) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    return [bool](Select-String -LiteralPath $path -Pattern $pattern -Quiet)
}
function Throws([scriptblock] $block) {
    try { & $block | Out-Null; return $false } catch { return $true }
}
function Reset([string] $path) {
    if (Test-Path -LiteralPath $path) { [System.IO.Directory]::Delete($path, $true) }
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

Reset $WorkRoot
Write-Output "new-app.ps1 in $kit"
Write-Output ""

# A fresh copy must take the stack's file wherever the stack has one.
Write-Output "fresh copy, -Stack flutter"
& $script -Name fresh -Stack flutter -ProjectsRoot $WorkRoot | Out-Null
$fresh = Join-Path $WorkRoot 'fresh'
Check 'ci.yml comes from the stack' (Has "$fresh\.github\workflows\ci.yml" 'subosito/flutter-action')
Check 'settings.json comes from the stack' (Has "$fresh\.claude\settings.json" '"hooks"')
Check 'dependabot.yml comes from the stack' (Has "$fresh\.github\dependabot.yml" 'package-ecosystem: pub')
Check 'the stamp records the kit commit' (Has "$fresh\.kit-version" '^commit = [0-9a-f]{7,40}$')
Check 'the stamp records the stack' (Has "$fresh\.kit-version" '^stack  = flutter$')
Check 'git repo initialised' (Test-Path (Join-Path $fresh '.git'))

# The bug this file exists for: two sequential copy passes made -Existing keep the
# template's file over the stack's, shipping CI whose first step is `exit 1`.
Write-Output ""
Write-Output "-Existing on a repo that already has files"
$adopted = Join-Path $WorkRoot 'adopted'
New-Item -ItemType Directory -Force -Path $adopted | Out-Null
Set-Content "$adopted\README.md" '# the app''s own readme' -Encoding UTF8
& $script -Name adopted -Stack flutter -ProjectsRoot $adopted.Substring(0, $adopted.LastIndexOf([char]92)) -Existing | Out-Null
Check 'ci.yml still comes from the stack' (Has "$adopted\.github\workflows\ci.yml" 'subosito/flutter-action')
Check 'the placeholder CI stub is gone' (-not (Has "$adopted\.github\workflows\ci.yml" "Fill in the stack"))
Check 'settings.json still has the hook' (Has "$adopted\.claude\settings.json" '"hooks"')
# Get-Content -Raw keeps the byte-order mark that Set-Content -Encoding UTF8 writes,
# and Trim() does not count it as whitespace, so strip it explicitly.
$readme = (Get-Content "$adopted\README.md" -Raw).Trim([char]0xFEFF, ' ', "`r", "`n", "`t")
Check "the repo's own file is kept (found '$readme')" ($readme -eq "# the app's own readme")

# -Update must move only what the kit changed, and never undo /kickoff.
Write-Output ""
Write-Output "-Update"
& $script -Name fresh -ProjectsRoot $WorkRoot -Update | Out-Null
Check 'a project level with the kit copies nothing' (-not (Test-Path "$fresh\CLAUDE.md.kit-new"))

# A shallow clone (actions/checkout defaults to fetch-depth 1) grafts history so the
# root commit IS HEAD. Updating from HEAD to HEAD is a no-op that would pass every
# check below for the wrong reason, so say so instead of pretending to test it.
$old = (git -C $kit rev-list --max-parents=0 HEAD 2>$null | Select-Object -Last 1)
if ($old -and $old -eq (git -C $kit rev-parse HEAD 2>$null)) { $old = $null }
if ($old) {
    (Get-Content "$fresh\.kit-version" -Raw) -replace 'commit = [0-9a-f]+', "commit = $old" |
        Set-Content "$fresh\.kit-version" -Encoding UTF8
    (Get-Content "$fresh\CLAUDE.md" -Raw).Replace('{{APP_NAME}}', 'Habit Tracker') |
        Set-Content "$fresh\CLAUDE.md" -Encoding UTF8
    [System.IO.Directory]::Delete((Join-Path $fresh '.claude\skills\kickoff'), $true)

    & $script -Name fresh -ProjectsRoot $WorkRoot -Update | Out-Null
    Check "a file /kickoff filled in is not overwritten" (Has "$fresh\CLAUDE.md" 'Habit Tracker')
    Check 'its new version lands as .kit-new' (Test-Path "$fresh\CLAUDE.md.kit-new")
    Check 'the stamp waits for the merge' (Has "$fresh\.kit-version" "commit = $old")
    Check 'a file the app deleted stays deleted' (-not (Test-Path (Join-Path $fresh '.claude\skills\kickoff')))
} else {
    Write-Output "  skip  -Update from an older commit (no git history here)"
}

# -DryRun must not touch the disk, so CI can run it on every push.
Write-Output ""
Write-Output "-DryRun"
$out = & $script -Name dry -Stack flutter -ProjectsRoot $WorkRoot -DryRun
Check 'nothing is created' (-not (Test-Path (Join-Path $WorkRoot 'dry')))
Check 'it still reports what it would copy' ([bool]($out -match 'would be copied'))

Write-Output ""
Write-Output "guards"
Check 'unknown stack is refused' (Throws { & $script -Name x -Stack nope -ProjectsRoot $WorkRoot })
Check 'copying onto an existing folder is refused' (Throws { & $script -Name fresh -Stack flutter -ProjectsRoot $WorkRoot })
Check '-Update on a folder the kit never made is refused' (Throws {
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkRoot 'plain') | Out-Null
    & $script -Name plain -ProjectsRoot $WorkRoot -Update
})
Check '-Existing with -Update is refused' (Throws { & $script -Name fresh -ProjectsRoot $WorkRoot -Existing -Update })

Write-Output ""
if ($failures) { Write-Output "$failures check(s) failed."; exit 1 }
Write-Output 'All checks passed.'
