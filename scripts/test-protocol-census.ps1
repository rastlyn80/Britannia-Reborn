# Live protocol census against the local shard (docs/PROTOCOL_BLUEPRINT.md).
# Logs in with the development account: run only while the owner's client is closed.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root\.tools\godot\*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
if (!(Test-Path "$root\Server\credentials.local.json")) { throw 'Configure and start the local server first' }
$credentials = Get-Content "$root\Server\credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
  & $godot --headless --path "$root\Viewer" --script res://Network/ProtocolCensus.gd
  if ($LASTEXITCODE) { throw 'Protocol census found unhandled packets' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
