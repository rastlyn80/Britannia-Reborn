$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (!(Test-Path "$root/outputs/britain/atlas.json")) { & "$PSScriptRoot/prepare-britain.ps1" }
& "$PSScriptRoot/bake-britain.ps1"
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*win64.exe" | Select-Object -First 1).FullName
& $godot --path "$root/Viewer" res://Atlas.tscn -- "--atlas=$root/outputs/britain/atlas.json"
