# Parses the GDScript files a bridge code job changed in its sandbox copy
# (scripts/code-preview.ps1 -New), so the in-game agent can fix its own errors
# before offering the change. Prints "CHECK PASS" or each file's errors.
#   scripts/bridge-check.ps1 <copy id>
param([Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{2,40}$')][string]$Id)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$copy = Join-Path $root "work/code-previews/$Id/Viewer"
if (!(Test-Path $copy)) { throw "No sandbox copy $Id" }
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$changes = & "$PSScriptRoot/code-preview.ps1" -Id $Id -Status
$files = @($changes | Where-Object { $_ -match '^(added|modified): Viewer/(.+\.gd)$' } | ForEach-Object { ($_ -replace '^(added|modified): Viewer/', '') })
if ($files.Count -eq 0) { Write-Output 'CHECK PASS (no GDScript changed)'; exit 0 }
$empty = Join-Path $root 'work/dev-edit-bridge/no-input.txt'
if (!(Test-Path $empty)) { Set-Content -LiteralPath $empty -Value '' -NoNewline }
$failed = $false
foreach ($file in $files) {
  $output = Get-Content -LiteralPath $empty | & $godot --headless --path $copy --check-only --script "res://$($file -replace '\\','/')" 2>&1 | Out-String
  $errors = @($output -split "`r?`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
  if ($errors.Count) { $failed = $true; Write-Output "ERRORS in Viewer/${file}:"; $errors | ForEach-Object { Write-Output "  $_" } }
  else { Write-Output "ok: Viewer/$file" }
}
if ($failed) { exit 1 }
Write-Output 'CHECK PASS'
