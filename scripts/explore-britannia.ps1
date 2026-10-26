$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (!(Test-Path "$root/outputs/atlas/atlas.json")) { & "$PSScriptRoot/prepare-britannia.ps1" }
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*win64.exe" | Select-Object -First 1).FullName
& $godot --path "$root/Viewer" res://Atlas.tscn
