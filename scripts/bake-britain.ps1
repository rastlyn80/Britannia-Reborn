$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
& $godot --headless --path "$root/Viewer" --script res://Presentation/RegionalBake.gd
if ($LASTEXITCODE) { throw 'Joined Britain architecture bake failed' }
