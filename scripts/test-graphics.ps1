param([switch]$PreviewOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
$env:UO_GRAPHICS_OUTPUT = Join-Path $root 'outputs/validation'
try {
  $extra = @()
  if ($PreviewOnly) { $extra = @("--", "--preview-only") }
  & $godot --path "$root/Viewer" --script res://Network/GraphicsVisual.gd @extra
  if ($LASTEXITCODE) { throw 'Live graphics/traversal test failed' }
} finally {
  Remove-Item Env:UO_DEV_USER,Env:UO_DEV_PASSWORD,Env:UO_GRAPHICS_OUTPUT -ErrorAction SilentlyContinue
}
