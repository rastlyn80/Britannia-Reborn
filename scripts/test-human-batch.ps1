param([switch]$Live,[switch]$Visual,[switch]$Cosmetics,[switch]$Motion)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
& $godot --headless --path "$root/Viewer" --script res://Presentation/HumanBatchTests.gd
if ($LASTEXITCODE) { throw 'Human appearance/wardrobe regression checks failed' }
if (Test-Path "$root/Viewer/local-art/free-equipment-female/expansion/closed_helmet.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/CharacterExpansionTests.gd
  if ($LASTEXITCODE) { throw 'Expanded wardrobe/native appearance checks failed' }
}
& $godot --headless --path "$root/Viewer" --script res://Presentation/HumanMotionAudit.gd
if ($LASTEXITCODE) { throw 'Animation feasibility audit failed' }
if (Test-Path "$root/Viewer/local-art/free-equipment-female/motion/human-motion.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanMotionTests.gd
  if ($LASTEXITCODE) { throw 'Prepared human motion checks failed' }
}
if ($Live) {
  $engine=@('--path',"$root/Viewer",'--script','res://Network/HumanBatchLive.gd')
  $review=@()
  if ($Visual) { $review=@('--visual') } else { $engine=@('--headless')+$engine }
  if ($Cosmetics) { $review+=@('--cosmetics') }
  if ($Motion) { $review+=@('--motion') }
  & $godot @engine -- @review
  if ($LASTEXITCODE) { throw 'Local male/female creation/equipment/reconnect test failed' }
}
