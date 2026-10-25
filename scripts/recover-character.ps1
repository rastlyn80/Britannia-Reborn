param([switch]$DevelopmentAccount)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
  $extra = @()
  if ($DevelopmentAccount) { $extra = @('--','--development-account') }
  & $godot --headless --path "$root/Viewer" --script res://Network/RecoveryLive.gd @extra
  if ($LASTEXITCODE) { throw 'Character recovery was not confirmed by the server' }
} finally {
  Remove-Item Env:UO_DEV_USER,Env:UO_DEV_PASSWORD -ErrorAction SilentlyContinue
}
