$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
try {
 & $godot --headless --path "$root/Viewer" --script res://Network/SetupShops.gd
 if ($LASTEXITCODE) { throw 'Native vendor setup failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
