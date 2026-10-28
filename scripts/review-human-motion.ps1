param([string]$Clip='Jog',[ValidateSet('viking','sword','robe','kilt')][string]$Outfit='viking',[string]$Screenshot,[switch]$Compatibility)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$engine=@('--path',"$root/Viewer",'--script','res://Presentation/HumanMotionReview.gd')
if ($Compatibility) { $engine+=@('--rendering-method','gl_compatibility') }
$review=@("--clip=$Clip","--outfit=$Outfit")
if ($Screenshot) { $review+="--screenshot=$Screenshot" }
& $godot @engine -- @review
if ($LASTEXITCODE) { throw 'Human motion review failed' }
