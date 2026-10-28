# Populates the prepared Britain region with ModernUO's own spawners (vendors,
# townsfolk, town animals, crops, reagents, graveyard, wildlife and outdoor
# creatures) through the loopback-only PreviewSpawn command, checks that a
# repeated run creates nothing, and writes the audit to
# Server/runtime/Data/UltimaClonePreview/spawns.local.json. Needs the server
# running with the preview extension installed (scripts/build-preview-tools.ps1
# and a graceful restart). Back up Server/runtime/Saves first.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
 & $godot --headless --path "$root/Viewer" --script res://Network/SpawnLive.gd
 if ($LASTEXITCODE) { throw 'Live bounded spawner population failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
