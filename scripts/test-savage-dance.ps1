$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
Push-Location $root
try {
 & python -B scripts/prepare-savage-dance.py *> work/creatures/savages/dance-owned-prepare.log
 if ($LASTEXITCODE) {throw 'Original tribal dance inputs/conversion failed'}
 & $godot --headless --path Viewer --script res://Presentation/PrepareSavageDance.gd *> work/creatures/savages/dance-owned-retarget.log
 if ($LASTEXITCODE -or (Select-String work/creatures/savages/dance-owned-retarget.log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original dance modern-rig retarget failed'}
 & $godot --path Viewer --script res://Presentation/SavageDanceTests.gd *> work/creatures/savages/dance-tests.log
 if ($LASTEXITCODE -or (Select-String work/creatures/savages/dance-tests.log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original dance off-grid skin/GPU checks failed'}
 & python -B scripts/check-savage-dance.py
 if ($LASTEXITCODE) {throw 'Exact prepared dance evidence failed'}
} finally {Pop-Location}
