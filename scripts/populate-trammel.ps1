# Populates all of Trammel with ModernUO's own world content (decorations,
# doors, signs, teleporters, public moongates, standard spawners) through the
# loopback-only PreviewTrammel command, then saves. Existing items are kept,
# so a repeat adds nothing. Needs the server running with the preview
# extension installed (scripts/build-preview-tools.ps1 and a restart).
# The saves are backed up to Server/runtime/Backups/BeforeTrammel-<time> first.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$saves = Join-Path $root 'Server/runtime/Saves'
$backup = Join-Path $root ("Server/runtime/Backups/BeforeTrammel-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $saves -Destination $backup -Recurse
Write-Output "Saves backed up to $backup"
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
 & $godot --headless --path "$root/Viewer" --script res://Network/TrammelLive.gd
 if ($LASTEXITCODE) { throw 'Live Trammel population failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
