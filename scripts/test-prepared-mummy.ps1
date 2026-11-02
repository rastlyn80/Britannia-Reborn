param([switch]$Prepare)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
Push-Location $root
try {
 if ($Prepare) {
  & "$root/.tools/pyenv/Scripts/python.exe" -B scripts/prepare-source-mummy.py --prepare --cabinet-members *> work/creatures/mummies/batch-source-prepare.log
  if ($LASTEXITCODE) {throw 'Original Mummy cabinet/source conversion failed'}
 }
 & python -B scripts/prepare-source-mummy.py --check-prepared
 if ($LASTEXITCODE) {throw 'Mummy source/converter/asset pins failed'}
 & $godot --headless --path Viewer --editor --import *> work/creatures/mummies/batch-import.log
 if ($LASTEXITCODE -or (Select-String work/creatures/mummies/batch-import.log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load script' -Quiet)) {throw 'Mummy headless resource import failed'}
 & $godot --headless --path Viewer --script res://Presentation/BakeSourceMummyGround.gd *> work/creatures/mummies/batch-ground-bake.log
 if ($LASTEXITCODE -or (Select-String work/creatures/mummies/batch-ground-bake.log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Mummy actual imported residual measurements failed'}
 foreach ($trial in @(@('MummySourcePoseTests','source-poses'),@('MummyRuntimeTests','runtime-tests'),@('MummyTerrainTests','terrain-tests'),@('MummyDeathTests','death-tests'))) {
  $started=[DateTime]::UtcNow
  & $godot --headless --path Viewer --script "res://Presentation/$($trial[0]).gd" *> "work/creatures/mummies/$($trial[1]).log"
  if ($LASTEXITCODE -or (Select-String "work/creatures/mummies/$($trial[1]).log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Mummy candidate test failed: $($trial[0])"}
  $report=Get-Item "work/creatures/mummies/$($trial[1]).json"
  if ($report.LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Mummy candidate trial did not write fresh evidence'}
 }
 & python -B scripts/check-prepared-mummy.py --runtime
 if ($LASTEXITCODE) {throw 'Exact Mummy candidate runtime evidence failed'}
 Write-Output 'Mummy candidate headless stages pass. No registry acceptance, networking, GPU or desktop interaction.'
} finally {Pop-Location}
