param([switch]$Compatibility)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$renderArgs = @()
if ($Compatibility) { $renderArgs = @('--rendering-method','gl_compatibility') }
& $godot @renderArgs --path "$root/Viewer" --script res://Presentation/ServerEnvironmentVisual.gd
if ($LASTEXITCODE) { throw 'Rendered server environment checks failed' }
