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
        foreach ($entry in (Get-RelativeFiles $root).GetEnumerator()) { $map[$entry.Key] = $entry.Value }
    }
    return $map
}

# Relative path -> full path for every file under $root.
#
# Never cut the root off an enumerated path by its length: the caller's spelling of
# a directory and the spelling Get-ChildItem reports back are not always the same
# one. -ProjectsRoot given as an 8.3 short path (GitHub's Windows runners set TEMP
# to one) comes back expanded, so Substring removed the wrong number of characters,
# every relative key was mangled, and a repo's own README.md was not recognised as
# already present -- so -Existing overwrote it with the template's. Let the provider
# do the arithmetic instead.
function Get-RelativeFiles([string] $root) {
    $map = [ordered]@{}
    if (-not (Test-Path -LiteralPath $root)) { return $map }
    $prefix = '.' + $sep
    Push-Location -LiteralPath $root
    try {
        foreach ($item in (Get-ChildItem -Recurse -File -Force)) {
            $rel = Resolve-Path -LiteralPath $item.FullName -Relative
            if ($rel.StartsWith($prefix)) { $rel = $rel.Substring($prefix.Length) }
            $map[$rel] = $item.FullName
        }
    } finally {
        Pop-Location
    }
    return $map
}

# A file the kit still has {{PLACEHOLDERS}} in is one /kickoff rewrote with this app's
# name, commands and version, so -Update must never overwrite the app's copy.
#
# The reverse does not hold. A file with no placeholder in it can still carry this
# app's own settings -- a version lookup pointed into a subdirectory, a Dependabot
# `directory:` -- and nothing here can see that. "No placeholders" means "the kit
# wrote every line of its copy", never "safe to overwrite".
function Test-Templated([string] $path) {
    return [bool](Select-String -LiteralPath $path -Pattern '\{\{[A-Z_]+\}\}' -Quiet)
}

# Content, ignoring how the lines end. These files cross between the kit and an app
# through git's `text=auto`, so one side holds CRLF and the other LF for text that is
# character for character the same. Comparing the bytes called four of seven files in
# a real repo stale when nothing about them had changed, which is how a check earns
# being ignored. ReadAllText also drops a byte-order mark, so that cannot differ either.
function Test-SameContent([string] $a, [string] $b) {
    if (-not (Test-Path -LiteralPath $a) -or -not (Test-Path -LiteralPath $b)) { return $false }
    $left = [System.IO.File]::ReadAllText($a).Replace("`r`n", "`n")
    $right = [System.IO.File]::ReadAllText($b).Replace("`r`n", "`n")
    return $left -eq $right
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
#
# Only the kit's own paths are ever asked about, so ask about exactly those rather
# than enumerating the destination. Walking it whole meant walking a real project's
# build/ tree, where Gradle's transform directories run past the 260-character path
# limit and Resolve-Path fails outright -- so -Existing crashed on the first Flutter
# app it was pointed at, which is the case it exists for.
$before = @{}
foreach ($rel in $files.Keys) {
    if (Test-Path -LiteralPath (Join-Path $dest $rel)) { $before[$rel] = $true }
}

$copied = New-Object System.Collections.Generic.List[string]
$kept = New-Object System.Collections.Generic.List[string]
$review = New-Object System.Collections.Generic.List[string]
$added = New-Object System.Collections.Generic.List[string]
$ownedByApp = New-Object System.Collections.Generic.List[string]

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
        # Keeping a file is right; keeping it silently is not. A repo adopting the kit
        # usually has older copies of the kit's own tooling, and -Existing used to leave
        # every one of them frozen while stamping .kit-version at the current commit --
        # so -Update then reported "already up to date" and those copies were never
        # reachable again. Say which differ, and for the ones the kit wrote every line
        # of, put its version beside them to read against.
        $kept.Add($rel)
        if (-not (Test-SameContent $source $target)) {
            if (Test-Templated $source) {
                # This app filled these in, or wrote its own. Differing is expected.
                $ownedByApp.Add($rel)
            } else {
                if (-not $DryRun) { Copy-Item -LiteralPath $source -Destination "$target.kit-new" -Force }
                $review.Add($rel)
            }
        }
        continue
    }

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    $copied.Add($rel)
}

foreach ($rel in $kept) {
    if ($review -contains $rel) { Write-Output "differs $rel" }
    elseif ($ownedByApp -contains $rel) { Write-Output "theirs  $rel" }
    else { Write-Output "kept    $rel" }
}
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

# The stamp only lands once nothing is left to merge, so an unmerged .kit-new is
# never forgotten: the next run offers it again. On a fresh copy there is nothing to
# merge, so it always lands. Stamping while copies are still stale would be the
# worst outcome of all -- -Update would then answer "already up to date".
if (-not $DryRun -and $review.Count -eq 0) { Write-Stamp }

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
} elseif ($Existing) {
    Write-Output "Added $($copied.Count) file(s) to $dest (stack: $Stack); kept $($kept.Count) the repo already had."
    if ($review.Count) {
        Write-Output ""
        Write-Output "$($review.Count) kept file(s) differ from the kit's. Its versions sit beside them as .kit-new."
        Write-Output "Read both before merging: a file with no placeholder in it can still hold this app's own"
        Write-Output "settings -- a version lookup pointed into a subdirectory, a Dependabot directory -- and"
        Write-Output "nothing here can see that. Merge what belongs, delete the .kit-new, then run -Existing"
        Write-Output "again to record the stamp."
    }
    if ($ownedByApp.Count) {
        Write-Output ""
        Write-Output "$($ownedByApp.Count) kept file(s) this app fills in for itself also differ. That is expected;"
        Write-Output "compare them against $kit by hand only if something there looks out of date:"
        foreach ($rel in $ownedByApp) { Write-Output "  $rel" }
    }
    if ($review.Count) {
        Write-Output ""
        Write-Output "No $stampName written yet: -Update would otherwise answer 'already up to date' while the"
        Write-Output "stale copies above are still in place."
    } else {
        Write-Output "$stampName records the kit commit, so -Update works from here."
    }
    Write-Output "Review 'git status' and 'git diff' in that folder, then commit on a branch."
} else {
    Write-Output "Kit copied to $dest (stack: $Stack). $stampName records the kit commit."
    Write-Output "Next: open Claude Code in that folder and run /kickoff."
}
