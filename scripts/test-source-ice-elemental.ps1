param([switch]$Prepare)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$work=Join-Path $root 'work/creatures/ice-elemental'
New-Item -ItemType Directory -Force $work | Out-Null
Push-Location $root
try {
 if ($Prepare) {
  & "$root/.tools/pyenv/Scripts/python.exe" -B scripts/prepare-source-ice-elemental.py --prepare --cabinet-members *> "$work/batch-prepare.log"
  if ($LASTEXITCODE) {throw 'Original Ice cabinet-member/source conversion failed'}
 }
 & python -B scripts/prepare-source-ice-elemental.py --check-inputs
 if ($LASTEXITCODE) {throw 'Original Ice source/cabinet/native declaration pins failed'}
 foreach ($trial in @('BakeIceElementalGround','IceElementalSourceTests')) {
  $started=[DateTime]::UtcNow
  & $godot --headless --path Viewer --script "res://Presentation/$trial.gd" *> "$work/batch-$trial.log"
  if ($LASTEXITCODE -or (Select-String "$work/batch-$trial.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original Ice source stage failed: $trial"}
  if ($trial -eq 'IceElementalSourceTests' -and (Get-Item "$work/source-poses.json").LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Ice source stage did not produce fresh proof'}
 }
 & python -B scripts/check-source-ice-elemental.py
 if ($LASTEXITCODE) {throw 'Exact original Ice source/preparation/curve proof failed'}
} finally {Pop-Location}
