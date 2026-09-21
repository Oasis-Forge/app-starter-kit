<#
.SYNOPSIS
Checks the flutter stack's format hook, which every edit in a Flutter app runs and
which nothing in the kit executed. It must never fail a tool call, must leave
non-Dart files alone, and must format with the SDK FLUTTER_ROOT names before it
falls back to a path that only exists on one machine.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tests\test-format-hook.ps1
#>
param(
    [string] $WorkRoot = (Join-Path $env:TEMP 'kit-hook-tests'),
    [string] $Hook = ''
)
$ErrorActionPreference = 'Stop'

$kit = Split-Path -Parent $PSScriptRoot
$hook = if ($Hook) { $Hook } else { Join-Path $kit 'stacks\flutter\files\.claude\hooks\format-dart.ps1' }
$failures = 0

function Check([string] $name, [bool] $ok) {
    if ($ok) { Write-Output "  ok    $name" } else { Write-Output "  FAIL  $name"; $script:failures++ }
}
# Runs the hook the way Claude Code does: the tool's payload as JSON on stdin.
function Invoke-Hook([string] $json) {
    $json | powershell -NoProfile -ExecutionPolicy Bypass -File $hook | Out-Null
    return $LASTEXITCODE
}
function Payload([string] $path) {
    return '{"tool_input":{"file_path":"' + $path.Replace('\', '\\') + '"}}'
}

if (Test-Path -LiteralPath $WorkRoot) { Remove-Item -LiteralPath $WorkRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
Write-Output "format-dart.ps1 in $kit"
Write-Output ""

# A stand-in SDK whose dart.bat records how it was called instead of formatting.
$sdk = Join-Path $WorkRoot 'sdk'
$log = Join-Path $WorkRoot 'calls.txt'
New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'bin') | Out-Null
Set-Content (Join-Path $sdk 'bin\dart.bat') "@echo off`r`necho %*>> `"$log`"" -Encoding ASCII
$dartFile = Join-Path $WorkRoot 'a.dart'
$textFile = Join-Path $WorkRoot 'a.txt'
Set-Content $dartFile 'void main() {}' -Encoding ASCII
Set-Content $textFile 'not dart' -Encoding ASCII

Write-Output "with FLUTTER_ROOT set"
$env:FLUTTER_ROOT = $sdk
Check 'a Dart file exits 0' ((Invoke-Hook (Payload $dartFile)) -eq 0)
$calls = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
Check 'and is formatted with the SDK FLUTTER_ROOT names' ($calls -match '^format ')
Check 'with that file as the argument' ($calls -match [regex]::Escape($dartFile))

Remove-Item $log -Force -ErrorAction SilentlyContinue
Check 'a non-Dart file exits 0' ((Invoke-Hook (Payload $textFile)) -eq 0)
Check 'and is left alone' (-not (Test-Path $log))

Write-Output ""
Write-Output "never failing the tool call"
Check 'a payload with no file path exits 0' ((Invoke-Hook '{"tool_input":{}}') -eq 0)
Check 'input that is not JSON exits 0' ((Invoke-Hook 'not json at all') -eq 0)
Check 'an empty payload exits 0' ((Invoke-Hook '') -eq 0)
Check 'a Dart file that does not exist exits 0' ((Invoke-Hook (Payload (Join-Path $WorkRoot 'missing.dart'))) -eq 0)

Write-Output ""
if ($failures) { Write-Output "$failures check(s) failed."; exit 1 }
Write-Output 'All checks passed.'
