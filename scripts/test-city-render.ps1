param([switch]$Compatibility)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$mode = if ($Compatibility) { @('--rendering-method','gl_compatibility') } else { @() }
& $godot @mode --path "$root/Viewer" --script res://Presentation/CityRenderCheck.gd -- --city --hide-ui
if ($LASTEXITCODE) { throw 'City near/distant ownership render check failed' }
