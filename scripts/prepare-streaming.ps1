param([string]$Dataset,[switch]$Modern,[switch]$Classic)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$extra = @()
if ($Dataset) { $extra = @("--dataset=$Dataset") }
# Without -Modern/-Classic the bake follows the in-game Britain setting
# (user://graphics.cfg); each mode keeps its own prepared cache.
if ($Modern) { $extra += '--modern-britain' } elseif ($Classic) { $extra += '--classic-britain' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/BakeStreaming.gd -- @extra
if ($LASTEXITCODE) { throw 'Prepared streaming conversion failed; original UO data remains unchanged' }
