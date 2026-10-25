$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force "$root/outputs/validation" | Out-Null
& $godot --path "$root/Viewer" --script res://Presentation/ContactCapture.gd
if ($LASTEXITCODE) { throw 'Interior/stair capture failed' }
