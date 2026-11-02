param([switch]$Capture)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
Push-Location $root
try {
 & python -B scripts/prepare-source-juka.py --check-inputs
 if ($LASTEXITCODE) {throw 'Juka original inputs changed'}
 & $godot --headless --path Viewer --editor --import *> work/creatures/juka/batch-import.log
 if ($LASTEXITCODE) {throw 'Juka resource import failed'}
 & python -B scripts/configure-creature-imports.py juka
 if ($LASTEXITCODE -eq 3) {
  & $godot --headless --path Viewer --editor --import *> work/creatures/juka/batch-precision-import.log
  if ($LASTEXITCODE) {throw 'Juka precision import failed'}
 } elseif ($LASTEXITCODE) {throw 'Juka import settings failed'}
 foreach ($test in @('JukaSourcePoseTests','JukaTransitionTests','CreatureTests')) {
  $started=[DateTime]::UtcNow
  & $godot --headless --path Viewer --script "res://Presentation/$test.gd" -- --family=juka *> "work/creatures/juka/batch-$test.log"
  if ($LASTEXITCODE -or (Select-String "work/creatures/juka/batch-$test.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw "Juka source/transition/general gate failed: $test"}
  if ($test -eq 'CreatureTests') {
   $proof=Join-Path $root 'outputs/creatures/juka/validation.json'
   if (!(Test-Path $proof) -or (Get-Item $proof).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Juka general test did not write fresh evidence'}
   $receipt=Join-Path $root 'outputs/creatures/juka/pose-inputs.json'
   if (Test-Path $receipt) {
    Copy-Item -LiteralPath $receipt -Destination (Join-Path $root ('work/creatures/juka/pose-inputs-before-'+[Guid]::NewGuid().ToString('N')+'.json'))
    Remove-Item -LiteralPath $receipt
   }
   & python -B scripts/check-creature-evidence.py juka
   if ($LASTEXITCODE) {throw 'Fresh Juka general evidence does not match exact current inputs'}
  }
 }
 & $godot --path Viewer --script res://Presentation/CreatureAppearanceTests.gd -- --family=juka *> work/creatures/juka/batch-appearance.log
 if ($LASTEXITCODE) {throw 'Juka standard GPU gate failed'}
 foreach ($kind in @('juka_warrior','juka_mage')) {
  & $godot --path Viewer --script res://Presentation/JukaPresentationTests.gd -- "--kind=$kind" *> "work/creatures/juka/batch-$kind-avatar.log"
  if ($LASTEXITCODE -or (Select-String "work/creatures/juka/batch-$kind-avatar.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw "Juka actual-avatar gate failed: $kind"}
  if ($Capture) {
   & $godot --path Viewer --script res://Presentation/CreatureReview.gd -- --family=juka "--kind=$kind" --capture *> "work/creatures/juka/batch-$kind-capture.log"
   if ($LASTEXITCODE) {throw "Juka comparison capture failed: $kind"}
  }
 }
 & $godot --path Viewer --script res://Presentation/JukaMixedTerrainTests.gd *> work/creatures/juka/batch-mixed-terrain.log
 if ($LASTEXITCODE) {throw 'Juka actual full-skin mixed-plane gate failed'}
 & python -B scripts/check-prepared-juka.py --graphics
 if ($LASTEXITCODE) {throw 'Juka exact prepared graphics evidence failed'}
 Write-Output 'Prepared Juka graphics verified; native/weapon/final-art acceptance remains separate.'
} finally {Pop-Location}
