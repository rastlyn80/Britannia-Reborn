param([string]$Dataset)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$extra = @()
if ($Dataset) { $extra = @("--dataset=$Dataset") }
& $godot --headless --path "$root/Viewer" --script res://Presentation/BakeStreaming.gd -- @extra
if ($LASTEXITCODE) { throw 'Prepared streaming conversion failed; original UO data remains unchanged' }
