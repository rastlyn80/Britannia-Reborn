$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
python "$root/scripts/prepare-population.py"
if ($LASTEXITCODE) { throw 'Population input preparation failed' }
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
 & $godot --headless --path "$root/Viewer" --script res://Network/PopulationLive.gd
 if ($LASTEXITCODE) { throw 'Live bounded population/idempotency check failed' }
 python "$root/scripts/prepare-population.py" --catalog-only
 if ($LASTEXITCODE) { throw 'Local item presentation catalogue export failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }

& "$root/scripts/setup-preview-shops.ps1"
& "$root/scripts/prepare-client-art.ps1"
