param([switch]$VerifyOnly,[switch]$Gpu,[switch]$Review)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 & python -B scripts/build-human-coverage-registry.py
 if ($LASTEXITCODE) { throw 'Native registry failed' }
 if (!$VerifyOnly) {
  $blender=(Get-ChildItem .tools/blender/*/blender.exe|Select-Object -First 1).FullName
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-wardrobe50.py
  if ($LASTEXITCODE) { throw 'Male wardrobe export failed' }
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-wardrobe50.py -- --female
  if ($LASTEXITCODE) { throw 'Female wardrobe export failed' }
 }
 & python -B scripts/validate-human-wardrobe50.py
 if ($LASTEXITCODE) { throw 'Source/native/bind/topology validation failed' }
 & python -B scripts/validate-human-coverage.py
 if ($LASTEXITCODE) { throw 'Full export validation failed' }
 $godot=(Get-ChildItem .tools/godot/*console.exe|Select-Object -First 1).FullName
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) { throw 'Asset import failed' }
 foreach ($test in @('HumanCoverageTests','HumanWardrobe50LayerTests')) {
  & $godot --headless --path Viewer --script "res://Presentation/$test.gd"
  if ($LASTEXITCODE) { throw "$test failed" }
 }
 if ($Gpu) {
  foreach ($test in @('HumanWardrobe50Tests','HumanWardrobe50HairTests','HumanWardrobe50CoverageTests')) {
   & $godot --path Viewer --script "res://Presentation/$test.gd"
   if ($LASTEXITCODE) { throw "$test failed" }
  }
 }
 if ($Review) {
  & $godot --path Viewer --script res://Presentation/HumanWardrobe50Review.gd
  if ($LASTEXITCODE) { throw 'Review capture failed' }
 }
 & ./scripts/build-human-catalogue.ps1 -NoOpen
} finally { Pop-Location }
