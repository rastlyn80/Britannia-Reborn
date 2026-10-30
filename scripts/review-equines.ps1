param([switch]$Capture)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
if (!(Test-Path "$root/Viewer/local-art/horses/warhorse.glb")) { throw 'Run scripts/prepare-horses.ps1 first.' }
$options=@()
if ($Capture) {
 $out=Join-Path $root 'outputs/equines'
 New-Item -ItemType Directory -Force $out|Out-Null
 $options+="--capture-dir=$out"
}
& $godot --path "$root/Viewer" --script res://Presentation/EquineReview.gd -- @options
if ($LASTEXITCODE) { throw 'Equine review failed' }
if ($Capture) {
 & python -B "$root/scripts/build-equine-gallery.py"
 if ($LASTEXITCODE) { throw 'Equine gallery build failed' }
}
