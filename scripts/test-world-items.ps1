param([switch]$Visual,[switch]$Compatibility)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
 $renderArgs = @('--headless')
 if ($Visual) { $renderArgs = @() }
 if ($Compatibility) { $renderArgs += @('--rendering-method','gl_compatibility') }
 $userArgs = @()
 if ($Visual) { $userArgs = @('--','--visual') }
 & $godot @renderArgs --path "$root/Viewer" --script res://Network/WorldItemsLive.gd @userArgs
 if ($LASTEXITCODE) { throw 'Live world-item interaction checks failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
