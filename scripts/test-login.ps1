$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root\.tools\godot\*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
& $godot --headless --path "$root\Viewer" --script res://Network/LoginTests.gd
if ($LASTEXITCODE) { throw 'Login protocol tests failed' }
if (!(Test-Path "$root\Server\credentials.local.json")) { throw 'Configure and start the local server before the live test' }
$credentials = Get-Content "$root\Server\credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
  & $godot --headless --path "$root\Viewer" --script res://Network/LoginSmoke.gd
  if ($LASTEXITCODE) { throw 'Live server login test failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
