$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
Push-Location $root
try {
 # All stages are headless. Native server/GPU/terrain acceptance is separate.
 & python -B scripts/prepare-savage-dance.py *> work/creatures/savages/action-source-prepare.log
 if ($LASTEXITCODE) {throw 'Exact original dance preparation failed'}
 & $godot --headless --path Viewer --script res://Presentation/PrepareSavageDance.gd *> work/creatures/savages/action-retarget.log
 if ($LASTEXITCODE -or (Select-String work/creatures/savages/action-retarget.log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original dance retarget failed'}
 & $godot --headless --path Viewer --script res://Presentation/PrepareHumanDeathFloor.gd *> work/creatures/savages/death-floor-prepare.log
 if ($LASTEXITCODE -or (Select-String work/creatures/savages/death-floor-prepare.log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Exact human death-floor preparation failed'}
 foreach ($trial in @(@('HumanNPCMotionTests','human-npc-motion-tests'),@('SavageActionIntegrationTests','action-integration-tests'),@('HumanNPCGroundTests','ground-tests'),@('HumanDeathFloorTests','death-floor-tests'),@('HumanNPCDeathTests','death-tests'))) {
  $started=[DateTime]::UtcNow
  & $godot --headless --path Viewer --script "res://Presentation/$($trial[0]).gd" *> "work/creatures/savages/$($trial[1]).log"
  if ($LASTEXITCODE -or (Select-String "work/creatures/savages/$($trial[1]).log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Prepared NPC action trial failed: $($trial[0])"}
  $report=Get-Item "work/creatures/savages/$($trial[1]).json"
  if ($report.LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'NPC action evidence is stale'}
 }
 & python -B scripts/check-savage-actions.py
 if ($LASTEXITCODE) {throw 'Exact prepared NPC action evidence failed'}
} finally {Pop-Location}
