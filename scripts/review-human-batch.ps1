param([ValidateSet('base','viking','monk','robe','tunic','pants','boots','hood','skirt','kilt','guard','sword','hammer','staff')][string]$Outfit='viking',[ValidateSet('Idle','Walk','Run')][string]$Clip='Idle',[string]$Screenshot,[switch]$Compatibility)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$engine=@('--path',"$root/Viewer",'--script','res://Presentation/HumanBatchReview.gd')
if ($Compatibility) { $engine+=@('--rendering-method','gl_compatibility') }
$review=@("--outfit=$Outfit","--clip=$Clip")
if ($Screenshot) { $review+="--screenshot=$Screenshot" }
& $godot @engine -- @review
if ($LASTEXITCODE) { throw 'Human batch review failed' }
