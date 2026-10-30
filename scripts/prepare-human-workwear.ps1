param([switch]$VerifyOnly,[switch]$Gpu,[switch]$Review)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 New-Item -ItemType Directory -Force work/human-workwear,outputs/human-workwear | Out-Null
 $godot=(Get-ChildItem '.tools/godot/*console.exe'|Select-Object -First 1).FullName
 $blender=(Get-ChildItem '.tools/blender/*/blender.exe'|Select-Object -First 1).FullName
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 $pins=Get-Content scripts/human-workwear-inputs.json -Raw | ConvertFrom-Json
 foreach ($file in $pins.files.PSObject.Properties) {
  if ((Get-FileHash -LiteralPath $file.Name).Hash.ToLowerInvariant() -ne $file.Value) {throw "Changed workwear input $($file.Name)"}
 }
 & python -B scripts/build-human-coverage-registry.py
 if ($LASTEXITCODE) {throw 'Workwear registry failed'}
 if (!$VerifyOnly) {
  foreach ($sex in @('male','female')) {
   $sexArgs=@();if ($sex -eq 'female') {$sexArgs=@('--','--female')}
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-workwear.py @sexArgs
   if ($LASTEXITCODE) {throw "$sex workwear build failed"}
  }
 }
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) {throw 'Workwear import failed'}
 if ($Gpu) {
  & $godot --path Viewer --script res://Presentation/HumanWorkwearTests.gd
  if ($LASTEXITCODE) {throw 'Workwear GPU checks failed'}
  & $godot --path Viewer --script res://Presentation/HumanWorkwearHairTests.gd
  if ($LASTEXITCODE) {throw 'Workwear hair checks failed'}
 }
 & $blender --background --factory-startup --python-exit-code 1 --python scripts/validate-human-workwear.py
 if ($LASTEXITCODE) {throw 'Workwear source/export checks failed'}
 if ($Review) {
  & $godot --path Viewer --script res://Presentation/HumanWorkwearReview.gd
  if ($LASTEXITCODE) {throw 'Workwear review failed'}
 }
} finally {Pop-Location}
