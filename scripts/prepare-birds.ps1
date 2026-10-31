param([switch]$VerifyOnly,[switch]$Install)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 $arguments=@('-B','scripts/prepare-bird-inputs.py')
 if ($VerifyOnly) {$arguments+='--verify-only'}
 & python @arguments
 if ($LASTEXITCODE) {throw 'Pinned bird input audit failed'}
 if ($VerifyOnly) {return}
 $blender=(Get-ChildItem "$root/.tools/blender/*/blender.exe"|Select-Object -First 1).FullName
 $godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
 $oldTemp=$env:TEMP;$oldTmp=$env:TMP
 try {
  $env:TEMP=Join-Path $root 'work/birds/temp';$env:TMP=$env:TEMP
  New-Item -ItemType Directory -Force $env:TEMP|Out-Null
  & $blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-bird.py
  if ($LASTEXITCODE) {throw 'Bird authoring failed'}
 } finally {$env:TEMP=$oldTemp;$env:TMP=$oldTmp}
 Copy-Item -LiteralPath "$root/work/birds/shrike/bird_yellow_billed_shrike/textures/bird_shrike1_sss.png" -Destination "$root/Viewer/local-art/birds/feather-tint-mask.png" -Force
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) {throw 'Bird import failed'}
 & $godot --headless --path Viewer --script res://Presentation/BirdMotionTests.gd
 if ($LASTEXITCODE) {throw 'Bird motion failed'}
 & python -B scripts/prepare-bird-inputs.py --verify-only --candidate
 if ($LASTEXITCODE) {throw 'Bird candidate envelope failed'}
 & $godot --path Viewer --script res://Presentation/BirdPresentationTests.gd -- --candidate=res://local-art/birds/candidate.json
 if ($LASTEXITCODE) {throw 'Bird rendered acceptance failed'}
 if ($Install) {
  & python -B scripts/prepare-bird-inputs.py --verify-only --install
  if ($LASTEXITCODE) {throw 'Bird receipt-gated installation failed'}
 }
} finally {Pop-Location}
