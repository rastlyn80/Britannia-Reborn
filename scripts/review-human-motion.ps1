param([string]$Clip='Jog',[ValidateSet('viking','sword','carry','robe','robe-sword','kilt')][string]$Outfit='viking',[string]$Screenshot,[switch]$Compatibility,[switch]$ComparePrepared,[float]$Angle=0,[ValidateSet('both','male','female')][string]$Sex='both')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$engine=@('--path',"$root/Viewer",'--script','res://Presentation/HumanMotionReview.gd')
if ($Compatibility) { $engine+=@('--rendering-method','gl_compatibility') }
$review=@("--clip=$Clip","--outfit=$Outfit")
if ($ComparePrepared) { $review+='--compare-prepared' }
$review+="--angle=$Angle"
$review+="--sex=$Sex"
if ($Screenshot) { $review+="--screenshot=$Screenshot" }
& $godot @engine -- @review
if ($LASTEXITCODE) { throw 'Human motion review failed' }
