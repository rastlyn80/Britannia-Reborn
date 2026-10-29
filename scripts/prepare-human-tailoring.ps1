param([switch]$VerifyOnly,[switch]$Gpu,[switch]$Review)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 New-Item -ItemType Directory -Force work/human-tailoring,outputs/human-tailoring | Out-Null
 $pins=Get-Content scripts/human-tailoring-inputs.json -Raw | ConvertFrom-Json
 foreach ($file in $pins.files.PSObject.Properties) {
  if ((Get-FileHash -LiteralPath $file.Name).Hash.ToLowerInvariant() -ne $file.Value) {throw "Changed tailoring input $($file.Name)"}
 }
 $godot=(Get-ChildItem '.tools/godot/*console.exe'|Select-Object -First 1).FullName
 $blender=(Get-ChildItem '.tools/blender/*/blender.exe'|Select-Object -First 1).FullName
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 & python -B scripts/build-human-coverage-registry.py
 if (!$VerifyOnly) {
  foreach ($sex in @('male','female')) {
   $sexArgs=@('--','--tailoring-only');if ($sex -eq 'female') {$sexArgs+= '--female'}
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-coverage-gear.py @sexArgs
   if ($LASTEXITCODE) {throw "$sex tailoring build failed"}
  }
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-coif-hair.py
  if ($LASTEXITCODE) {throw 'Coif hair layering failed'}
  & $godot --headless --path Viewer --editor --import
  if ($LASTEXITCODE) {throw 'Tailoring import failed'}

 }
 & python -B scripts/validate-human-tailoring.py
 if ($LASTEXITCODE) {throw 'Tailoring source/export checks failed'}
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) {throw 'Fitted art import failed'}
 if ($Gpu) {
  & $godot --path Viewer --script res://Presentation/HumanTailoringTests.gd
  if ($LASTEXITCODE) {throw 'Tailoring GPU checks failed'}
  & $godot --path Viewer --script res://Presentation/HumanTailoringHairTests.gd
  if ($LASTEXITCODE) {throw 'Tailoring long-hair checks failed'}
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/validate-held-accessories.py
  if ($LASTEXITCODE) {throw 'Actual posed accessory geometry checks failed'}
 }
 if ($Review) {
  & $godot --path Viewer --script res://Presentation/HumanTailoringReview.gd
  if ($LASTEXITCODE) {throw 'Tailoring review failed'}
 }
} finally {Pop-Location}
