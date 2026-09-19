<#
.SYNOPSIS
Copies the app starter kit into a project folder and starts a git repo there,
and brings later kit fixes back down into a project that already has it.

.EXAMPLE
.\new-app.ps1 -Name habit-tracker -Stack flutter

.EXAMPLE
.\new-app.ps1 -Name "an existing app" -Stack flutter -Existing
Adds only the kit files the existing project doesn't have yet.

.EXAMPLE
.\new-app.ps1 -Name habit-tracker -Update
Re-copies the kit files that changed since this project was made. Files /kickoff
filled in land beside the original as <file>.kit-new, to merge by hand.

.EXAMPLE
.\new-app.ps1 -Name habit-tracker -Stack flutter -DryRun
Prints what would be copied and writes nothing.
#>
param(
    [Parameter(Mandatory = $true)] [string] $Name,
    [string] $Stack = 'none',
    [string] $ProjectsRoot = 'D:\Desktop\projects',
    [switch] $Existing,
    [switch] $Update,
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'

$kit = $PSScriptRoot
$dest = Join-Path $ProjectsRoot $Name
$stampName = '.kit-version'
$stamp = Join-Path $dest $stampName
$sep = [char]92

if ($Existing -and $Update) { throw 'Use -Existing to adopt the kit, or -Update to refresh it, not both.' }

# -Update reads the stack, the kit commit and the copied paths from the stamp the
# first copy left behind.
$fromCommit = ''
$wasCopied = @{}
if ($Update) {
    if (-not (Test-Path -LiteralPath $stamp)) {
        throw "$stamp doesn't exist, so this project didn't come from the kit (or predates $stampName). Use -Existing to adopt the kit into it."
    }
    $recorded = (Select-String -LiteralPath $stamp -Pattern '^stack\s*=\s*(.+)$').Matches.Groups[1].Value.Trim()
    if ($PSBoundParameters.ContainsKey('Stack') -and $Stack -ne $recorded) {
        throw "$stampName records stack '$recorded', not '$Stack'. Drop -Stack to use the recorded one."
    }
    $Stack = $recorded
    $commitMatch = Select-String -LiteralPath $stamp -Pattern '^commit\s*=\s*([0-9a-f]{7,40})$'
    if ($commitMatch) { $fromCommit = $commitMatch.Matches.Groups[1].Value.Trim() }
    # The paths the kit put here last time. A path listed here but gone from disk was
    # deleted on purpose (/kickoff removes its own skill), so -Update must not put it back.
    foreach ($line in (Select-String -LiteralPath $stamp -Pattern '^\s\s(\S.*)$').Matches) {
        $wasCopied[$line.Groups[1].Value.Trim().Replace([char]47, $sep)] = $true
    }
}

$overlay = Join-Path (Join-Path (Join-Path $kit 'stacks') $Stack) 'files'
if ($Stack -ne 'none' -and -not (Test-Path -LiteralPath $overlay)) {
    $stacksDir = Join-Path $kit 'stacks'
    $known = if (Test-Path -LiteralPath $stacksDir) { (Get-ChildItem -LiteralPath $stacksDir -Directory).Name -join ', ' } else { '(none found)' }
    throw "Unknown stack '$Stack'. Known: none, $known"
}
if ($Existing -or $Update) {
    if (-not (Test-Path -LiteralPath $dest)) { throw "$dest doesn't exist" }
} elseif (Test-Path -LiteralPath $dest) {
    throw "$dest already exists. Use -Existing to add the kit to it, or -Update to refresh its kit tooling."
}

# Relative path -> source file, with the stack overlay replacing the template's copy
# of a file. Resolved BEFORE anything is written, so the overlay wins whatever the
# switches are: copying the two trees in sequence made -Existing keep the template's
# file over the stack's, which shipped the placeholder CI that always exits 1.
function Resolve-KitFiles([string[]] $roots) {
    $map = [ordered]@{}
    foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object {
            $map[$_.FullName.Substring($root.Length).TrimStart($sep)] = $_.FullName
        }
    }
    return $map
}

# A file the kit still has {{PLACEHOLDERS}} in is one /kickoff rewrote with this app's
# name, commands and version, so -Update must never overwrite the app's copy.
function Test-Templated([string] $path) {
    return [bool](Select-String -LiteralPath $path -Pattern '\{\{[A-Z_]+\}\}' -Quiet)
}

$sources = @(Join-Path $kit 'template')
if ($Stack -ne 'none') { $sources += $overlay }
$files = Resolve-KitFiles $sources

# Which kit files actually changed since this project was copied. Without it, -Update
# would rewrite every kit-owned file on every run and bury the real change in noise.
$changed = $null
if ($Update -and $fromCommit) {
    $diff = git -C $kit diff --name-only "$fromCommit" HEAD -- template stacks 2>$null
    if ($LASTEXITCODE -eq 0) {
        $changed = @{}
        foreach ($p in $diff) {
            if ($p) { $changed[(Join-Path $kit ($p -replace '/', $sep))] = $true }
        }
    } else {
        Write-Output "Kit commit $fromCommit is not in this clone, so every kit file is treated as changed."
    }
}

# The destination's file list as it was before this run, so -Existing can never
# report "kept" for a file this same run just created.
$before = @{}
if (Test-Path -LiteralPath $dest) {
    Get-ChildItem -LiteralPath $dest -Recurse -File -Force | ForEach-Object {
        $before[$_.FullName.Substring($dest.Length).TrimStart($sep)] = $true
    }
}

$copied = New-Object System.Collections.Generic.List[string]
$kept = New-Object System.Collections.Generic.List[string]
$review = New-Object System.Collections.Generic.List[string]
$added = New-Object System.Collections.Generic.List[string]

if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }

foreach ($rel in $files.Keys) {
    $source = $files[$rel]
    $target = Join-Path $dest $rel

    if ($Update) {
        if ($changed -and -not $changed.ContainsKey($source)) { continue }
        if (-not $before.ContainsKey($rel)) {
            # The app had it and removed it: leave it removed.
            if ($wasCopied.ContainsKey($rel)) { continue }
            # New in the kit since this project was made: safe to add outright.
            $added.Add($rel)
        } elseif (Test-Templated $source) {
            # The app owns its copy. Put the kit's new one beside it to merge by hand,
            # so a fix to a skill or a workflow still reaches a project already built.
            if (-not $DryRun) { Copy-Item -LiteralPath $source -Destination "$target.kit-new" -Force }
            $review.Add($rel)
            continue
        }
    } elseif ($Existing -and $before.ContainsKey($rel)) {
        $kept.Add($rel)
        continue
    }

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    $copied.Add($rel)
}

foreach ($rel in $kept) { Write-Output "kept    $rel" }
foreach ($rel in $copied) { if ($added -contains $rel) { Write-Output "added   $rel" } else { Write-Output "copied  $rel" } }
foreach ($rel in $review) { Write-Output "review  $rel.kit-new" }

# The stamp is what makes -Update possible: it records the kit commit this project
# came from and every path the kit owns in it.
function Write-Stamp() {
    $commit = (git -C $kit rev-parse HEAD 2>$null)
    if (-not $commit) { $commit = 'unknown' }
    $origin = (git -C $kit remote get-url origin 2>$null)
    if (-not $origin) { $origin = 'unknown' }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Which app starter kit this project came from, and which files it owns.')
    $lines.Add('# `new-app.ps1 -Name <this folder> -Update` re-copies the kit files that')
    $lines.Add('# changed since, so a kit fix reaches a project that was already built.')
    $lines.Add("kit    = $origin")
    $lines.Add("commit = $commit")
    $lines.Add("stack  = $Stack")
    $lines.Add('files:')
    foreach ($rel in ($files.Keys | Sort-Object)) { $lines.Add('  ' + $rel.Replace($sep, [char]47)) }
    Set-Content -LiteralPath $stamp -Value $lines -Encoding UTF8
}

# On -Update the stamp only moves once nothing is left to merge, so an unmerged
# .kit-new is never forgotten: the next -Update offers it again.
if (-not $DryRun -and (-not $Update -or $review.Count -eq 0)) { Write-Stamp }

if (-not $DryRun -and -not $Update -and -not (Test-Path -LiteralPath (Join-Path $dest '.git'))) {
    git -C $dest init -b main --quiet
}

Write-Output ""
if ($DryRun) {
    Write-Output "Dry run: $($copied.Count) file(s) would be copied to $dest (stack: $Stack). Nothing was written."
} elseif ($Update) {
    if ($copied.Count -eq 0 -and $review.Count -eq 0) {
        Write-Output "Already up to date with the kit (stack: $Stack)."
    } else {
        Write-Output "Updated $($copied.Count) kit-owned file(s) in $dest (stack: $Stack)."
        if ($review.Count) {
            Write-Output "$($review.Count) file(s) this app filled in have changed in the kit. Their new versions sit"
            Write-Output "beside them as .kit-new: merge what you want, delete the .kit-new, then run -Update again"
            Write-Output "to record the new kit commit."
        }
        Write-Output "Review 'git diff' in that folder, then commit on a branch."
    }
} else {
    Write-Output "Kit copied to $dest (stack: $Stack). $stampName records the kit commit."
    Write-Output "Next: open Claude Code in that folder and run /kickoff."
}
