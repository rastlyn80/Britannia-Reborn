param([switch]$Visual,[switch]$Compatibility)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
$mode = if ($Visual) { @() } else { @('--headless') }
if ($Compatibility) { $mode += @('--rendering-method','gl_compatibility') }
$extra = if ($Visual) { @('--capture-city') } else { @() }
try {
 & $godot @mode --path "$root/Viewer" --script res://Network/LiveCityCheck.gd -- --city @extra
 if ($LASTEXITCODE) { throw 'Live Britain streaming/traversal check failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
