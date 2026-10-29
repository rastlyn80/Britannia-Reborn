param([string]$Capture='', [switch]$Walk, [switch]$Run)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
if (!(Test-Path "$root/Viewer/local-art/horses/warhorse.glb")) { throw 'Prepare the free horse with scripts/prepare-horses.ps1 first.' }
$options=@()
if ($Capture) { $options+="--capture=$Capture" }
if ($Walk) { $options+='--walk' }
if ($Run) { $options+='--run' }
& $godot --path "$root/Viewer" --script res://Presentation/HorseReview.gd -- @options
if ($LASTEXITCODE) { throw 'Horse review failed' }
