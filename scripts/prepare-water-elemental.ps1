param([switch]$VerifyOnly,[switch]$Stage,[switch]$Install)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 & python -B scripts/prepare-water-elemental.py inputs
 if ($LASTEXITCODE) {throw 'Pinned CC0 water inputs changed'}
 if ($VerifyOnly) {return}
 if ($Install) {
  & python -B scripts/prepare-water-elemental.py install
  if ($LASTEXITCODE) {throw 'Water installation requires fresh presentation and native evidence'}
  & python -B scripts/test-water-distribution.py
  if ($LASTEXITCODE) {throw 'Water standalone distribution failed'}
  return
 }
 $godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 New-Item -ItemType Directory -Force work/creatures|Out-Null
 & $godot --headless --path Viewer --script res://Presentation/PrepareWaterElemental.gd *> work/creatures/water-prepare.log
 if ($LASTEXITCODE -or (Select-String -Path work/creatures/water-prepare.log -Pattern 'ERROR:' -Quiet)) {throw 'Water recipe failed'}
 & python -B scripts/prepare-water-elemental.py candidate
 if ($LASTEXITCODE) {throw 'Water candidate metadata failed'}
 & $godot --path Viewer --script res://Presentation/WaterElementalTrial.gd *> work/creatures/water-trial-runtime.log
 if ($LASTEXITCODE -or (Select-String -Path work/creatures/water-trial-runtime.log -Pattern 'ERROR:' -Quiet)) {throw 'Water rendered validation failed'}
 if ($Stage) {
  & python -B scripts/prepare-water-elemental.py stage
  if ($LASTEXITCODE) {throw 'Water local staging failed'}
 }
} finally {Pop-Location}
