param([switch]$Prepare)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
Push-Location $root
try {
 if ($Prepare) {
  & "$root/.tools/pyenv/Scripts/python.exe" -B scripts/prepare-source-solen-warriors.py --prepare *> work/creatures/solen-warriors/batch-prepare.log
  if ($LASTEXITCODE) {throw 'Original Solen warrior exact eight-influence conversion failed'}
 }
 & python -B scripts/test-eight-influence-skin.py
 if ($LASTEXITCODE) {throw 'Eight-influence bounds, normal repairs or legacy defaults failed'}
 & $godot --headless --path Viewer --editor --import *> work/creatures/solen-warriors/batch-import.log
 if ($LASTEXITCODE -or (Select-String work/creatures/solen-warriors/batch-import.log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load script' -Quiet)) {throw 'Original ant headless resource import failed'}
 foreach ($trial in @('BakeSolenWarriorGround','SolenWarriorSourceTests','SolenWarriorRuntimeTests','SolenWarriorTerrainTests')) {
  $started=[DateTime]::UtcNow
  & $godot --headless --path Viewer --script "res://Presentation/$trial.gd" *> "work/creatures/solen-warriors/batch-$trial.log"
  if ($LASTEXITCODE -or (Select-String "work/creatures/solen-warriors/batch-$trial.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original ant source stage failed: $trial"}
  $proof=if ($trial -eq 'SolenWarriorSourceTests') {'source-poses'} elseif ($trial -eq 'SolenWarriorRuntimeTests') {'runtime-tests'} elseif ($trial -eq 'SolenWarriorTerrainTests') {'terrain-tests'} else {''}
  if ($proof -and (Get-Item "work/creatures/solen-warriors/$proof.json").LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Ant source/runtime stage did not write fresh proof'}
 }
 & python -B scripts/check-solen-warrior-sources.py --terrain
 if ($LASTEXITCODE) {throw 'Exact original ant source/curve/eight-slot proof failed'}
} finally {Pop-Location}
