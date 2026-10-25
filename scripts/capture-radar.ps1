param([string]$DataDir = "$env:USERPROFILE\OneDrive\Electronic Arts\Ultima Online Classic")
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$out = Join-Path $root 'outputs/validation'
New-Item -ItemType Directory -Force $out | Out-Null
& $godot --path "$root/Viewer" -- "--screenshot=$out/britain-topdown.png" --hide-ui --map-view
if ($LASTEXITCODE) { throw 'Top-down rendering failed' }
& $godot --path "$root/Viewer" --script res://Presentation/RadarCapture.gd -- "--data=$DataDir" "--output=$out" "--overview=$out/britain-topdown.png"
if ($LASTEXITCODE) { throw 'Radar comparison failed' }
