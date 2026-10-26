param([string]$DataDir="$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic")
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
& $godot --headless --path "$root/Viewer" --script res://Presentation/RegionalLoadTest.gd
if ($LASTEXITCODE) { throw 'Britain models/ownership audit failed' }
python "$root/scripts/audit-atlas.py" --data-dir $DataDir --atlas "$root/outputs/britain"
if ($LASTEXITCODE) { throw 'Britain source parity failed' }
