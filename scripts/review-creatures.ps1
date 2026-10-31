param([string]$Family='bruins',[string]$Kind='',[switch]$Capture,[switch]$Validate,[switch]$MaterialTest)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$options=@("--family=$Family")
if ($Kind) {$options+="--kind=$Kind"}
if ($Capture) {$options+='--capture'}
$script=if ($Validate) {'CreatureTests'} elseif ($MaterialTest) {'CreatureAppearanceTests'} else {'CreatureReview'}
$arguments=@('--path',"$root/Viewer",'--script',"res://Presentation/$script.gd",'--')+$options
if ($Validate) {$arguments=@('--headless')+$arguments}
& $godot @arguments
if ($LASTEXITCODE) {throw "Creature $script failed: $Family"}
