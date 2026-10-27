param([switch]$Live,[switch]$Visual)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
& $godot --headless --path "$root/Viewer" --script res://Presentation/HumanBatchTests.gd
if ($LASTEXITCODE) { throw 'Human appearance/wardrobe regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/HumanMotionAudit.gd
if ($LASTEXITCODE) { throw 'Animation feasibility audit failed' }
if ($Live) {
  $engine=@('--path',"$root/Viewer",'--script','res://Network/HumanBatchLive.gd')
  $review=@()
  if ($Visual) { $review=@('--visual') } else { $engine=@('--headless')+$engine }
  & $godot @engine -- @review
  if ($LASTEXITCODE) { throw 'Local male/female creation/equipment/reconnect test failed' }
}
