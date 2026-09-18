<#
.SYNOPSIS
Copies the app starter kit into a project folder and starts a git repo there.

.EXAMPLE
.\new-app.ps1 -Name habit-tracker -Stack flutter

.EXAMPLE
.\new-app.ps1 -Name "an existing app" -Stack flutter -Existing
Adds only the kit files the existing project doesn't have yet.
#>
param(
    [Parameter(Mandatory = $true)] [string] $Name,
    [string] $Stack = 'none',
    [string] $ProjectsRoot = 'D:\Desktop\projects',
    [switch] $Existing
)
$ErrorActionPreference = 'Stop'

$kit = $PSScriptRoot
$dest = Join-Path $ProjectsRoot $Name
$overlay = Join-Path $kit "stacks\$Stack\files"

if ($Stack -ne 'none' -and -not (Test-Path -LiteralPath $overlay)) {
    $known = (Get-ChildItem -LiteralPath (Join-Path $kit 'stacks') -Directory).Name -join ', '
    throw "Unknown stack '$Stack'. Known: none, $known"
}
if ($Existing) {
    if (-not (Test-Path -LiteralPath $dest)) { throw "$dest doesn't exist" }
} elseif (Test-Path -LiteralPath $dest) {
    throw "$dest already exists. Use -Existing to add the kit to it."
}

function Copy-Tree([string] $from, [string] $to, [bool] $overwrite) {
    Get-ChildItem -LiteralPath $from -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($from.Length).TrimStart('\')
        $target = Join-Path $to $rel
        if ((Test-Path -LiteralPath $target) -and -not $overwrite) {
            Write-Host "kept    $rel"
            return
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    }
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
# A new app takes the stack's files over the template's; an existing one keeps its own.
Copy-Tree (Join-Path $kit 'template') $dest (-not $Existing)
if ($Stack -ne 'none') { Copy-Tree $overlay $dest (-not $Existing) }

if (-not (Test-Path -LiteralPath (Join-Path $dest '.git'))) {
    git -C $dest init -b main --quiet
}

Write-Host ""
Write-Host "Kit copied to $dest (stack: $Stack)."
Write-Host "Next: open Claude Code in that folder and run /kickoff."
