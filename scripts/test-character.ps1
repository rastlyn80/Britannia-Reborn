param([switch]$Visual,[string]$Screenshot)
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
 $userArgs = @()
 if ($Visual) { $renderArgs = @(); $userArgs = @('--','--visual','--city'); if ($Screenshot) { $userArgs += "--sheet-shot=$Screenshot" } }
 & $godot @renderArgs --path "$root/Viewer" --script res://Network/CharacterLive.gd @userArgs
 if ($LASTEXITCODE) { throw 'Live character sheet checks failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
