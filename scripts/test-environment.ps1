$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --headless --path "$root/Viewer" --script res://Presentation/EnvironmentTests.gd
if ($LASTEXITCODE) { throw 'Environment protocol tests failed' }
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
 & $godot --headless --path "$root/Viewer" --script res://Network/EnvironmentLive.gd
 if ($LASTEXITCODE) { throw 'Live server environment synchronization failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
