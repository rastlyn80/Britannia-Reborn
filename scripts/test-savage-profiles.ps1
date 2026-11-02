$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
Push-Location $root
try {
 & python -B scripts/prepare-savage-profiles.py
 if ($LASTEXITCODE) {throw 'Savage reference/native/human input pins failed'}
 & $godot --headless --path Viewer --script res://Presentation/SavagePaintAttributeTests.gd *> work/creatures/savages/attribute-tests.log
 if ($LASTEXITCODE -or (Select-String work/creatures/savages/attribute-tests.log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Savage source-free attribute/LOD/corpse preservation failed'}
 & $godot --path Viewer --script res://Presentation/SavageHumanProfileTests.gd *> work/creatures/savages/profile-tests.log
 if ($LASTEXITCODE -or (Select-String work/creatures/savages/profile-tests.log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Savage actual avatar/paint/hue/equipment/static corpse trial failed'}
 Write-Output 'Prepared Savage human profile trials pass. Native/masks/dance/ridgeback/terrain acceptance remains open; coverage unchanged.'
} finally {Pop-Location}
