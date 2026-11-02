param([switch]$Stage)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$work=Join-Path $root 'work/creatures/ice-elemental'
Push-Location $root
try {
 if ($Stage) {
  & python -B scripts/stage-ice-elemental-candidate.py *> "$work/candidate-stage.log"
  if ($LASTEXITCODE) {throw 'Original Ice candidate staging failed'}
 }
 & $godot --headless --path Viewer --editor --import *> "$work/candidate-import.log"
 if ($LASTEXITCODE -or (Select-String "$work/candidate-import.log" -Pattern 'SCRIPT ERROR:|ERROR: Failed to load script' -Quiet)) {throw 'Original Ice headless import failed'}
 & $godot --headless --path Viewer --script res://Presentation/ConfigureIceElementalImport.gd *> "$work/candidate-configure.log"
 if ($LASTEXITCODE) {throw 'Bounded original Ice import settings failed'}
 if ((Get-Content "$work/import-settings.json" -Raw | ConvertFrom-Json).changed -gt 0) {
  & $godot --headless --path Viewer --editor --import *> "$work/candidate-precise-import.log"
  if ($LASTEXITCODE) {throw 'Precise original Ice motion/atlas reimport failed'}
  & $godot --headless --path Viewer --script res://Presentation/ConfigureIceElementalImport.gd *> "$work/candidate-import-audit.log"
  if ($LASTEXITCODE -or (Get-Content "$work/import-settings.json" -Raw | ConvertFrom-Json).changed -ne 0) {throw 'Ice import settings did not settle'}
 }
 foreach ($trial in @('IceElementalImportTests','IceElementalRuntimeTests','IceElementalTerrainTests','IceElementalDeathTests')) {
  $started=[DateTime]::UtcNow
  & $godot --headless --path Viewer --script "res://Presentation/$trial.gd" *> "$work/candidate-$trial.log"
  if ($LASTEXITCODE -or (Select-String "$work/candidate-$trial.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Ice candidate stage failed: $trial"}
  $proof=if ($trial -eq 'IceElementalImportTests') {'import-fidelity'} elseif ($trial -eq 'IceElementalRuntimeTests') {'runtime-tests'} elseif ($trial -eq 'IceElementalTerrainTests') {'terrain-tests'} else {'death-tests'}
  if ((Get-Item "$work/$proof.json").LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Ice candidate stage did not write fresh proof'}
 }
 & python -B scripts/check-source-ice-elemental.py --candidate
 if ($LASTEXITCODE) {throw 'Exact original Ice candidate input/proof gate failed'}
} finally {Pop-Location}
