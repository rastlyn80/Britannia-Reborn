param([int]$Item=0x3ea3,[switch]$Capture,[switch]$Validate,[switch]$Clothing,[switch]$Live,[switch]$Pack)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
& $godot --headless --path "$root/Viewer" --editor --import
if ($LASTEXITCODE) {throw 'Mount art import failed'}
if ($Validate) {
 & python -B "$root/scripts/audit-distinct-mounts.py"
 if ($LASTEXITCODE) {throw 'Native mount identity audit failed'}
 foreach ($script in @('DistinctMountTests','OstardRidingTests','MountTerrainTests')) {
  $started=[DateTime]::UtcNow
  & $godot --headless --path "$root/Viewer" --script "res://Presentation/$script.gd"
  if ($LASTEXITCODE) {throw "$script failed"}
  $report=@{DistinctMountTests='skin-actions.json';OstardRidingTests='contact.json';MountTerrainTests='terrain.json'}[$script]
  $evidence=Join-Path $root "outputs/ostard-riding/$report"
  if (!(Test-Path $evidence) -or (Get-Item $evidence).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw "$script did not produce fresh evidence"}
  if ((Get-Content $evidence -Raw|ConvertFrom-Json).failures -ne 0) {throw "$script reported failures"}
 }
}
if ($Clothing) {
 & $godot --path "$root/Viewer" --script res://Presentation/DistinctMountClothingTests.gd
 if ($LASTEXITCODE) {throw 'Mount clothing coverage failed'}
}
if ($Live) { & "$root/scripts/test-horses.ps1" -Live -SkipContact -Ostards }
if ($Validate -or $Clothing -or $Live) {return}
$argsForReview=@("--item=$Item")
if ($Pack) {$argsForReview+='--pack'}
if ($Capture) {
 $output=Join-Path $root "outputs/ostard-riding/item-$Item"
 $argsForReview+="--capture-dir=$output"
}
& $godot --path "$root/Viewer" --script res://Presentation/MountRidingReview.gd -- @argsForReview
if ($LASTEXITCODE) {throw 'Mount review failed'}
