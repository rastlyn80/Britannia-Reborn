param([switch]$VerifyOnly,[switch]$Gpu,[switch]$Review)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 & python -B scripts/build-human-coverage-registry.py
 if ($LASTEXITCODE) { throw 'Native registry failed' }
 if (!$VerifyOnly) {
  $blender=(Get-ChildItem .tools/blender/*/blender.exe|Select-Object -First 1).FullName
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-frontier.py
  if ($LASTEXITCODE) { throw 'Male frontier export failed' }
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-frontier.py -- --female
  if ($LASTEXITCODE) { throw 'Female frontier export failed' }
 }
 & python -B scripts/validate-human-frontier.py
 if ($LASTEXITCODE) { throw 'Native/source/backing audit failed' }
 & python -B scripts/validate-human-coverage.py
 if ($LASTEXITCODE) { throw 'Full export validation failed' }
 $godot=(Get-ChildItem .tools/godot/*console.exe|Select-Object -First 1).FullName
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) { throw 'Godot import failed' }
 & $godot --headless --path Viewer --script res://Presentation/HumanCoverageTests.gd
 if ($LASTEXITCODE) { throw 'Human native/action checks failed' }
 if ($Gpu) {
  foreach ($test in @('HumanFrontierTests','HumanFrontierHairTests','HumanFrontierArmourTests')) {
   & $godot --path Viewer --script "res://Presentation/$test.gd"
   if ($LASTEXITCODE) { throw "$test failed" }
  }
 }
 if ($Review) {
  & $godot --path Viewer --script res://Presentation/HumanFrontierReview.gd
  if ($LASTEXITCODE) { throw 'Review frames failed' }
 }
 & ./scripts/build-human-catalogue.ps1 -NoOpen
} finally { Pop-Location }
