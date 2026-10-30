param([switch]$Gpu,[switch]$Live)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
& "$PSScriptRoot/prepare-horses.ps1" -VerifyOnly
& python -B "$PSScriptRoot/audit-equines.py"
if ($LASTEXITCODE) { throw 'Native equine identity audit failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/EquineTests.gd
if ($LASTEXITCODE) { throw 'Equine avatar/contact tests failed' }
if ($Gpu) {
 & $godot --path "$root/Viewer" --script res://Presentation/EquineAppearanceTests.gd
 if ($LASTEXITCODE) { throw 'Equine GPU appearance tests failed' }
}
if ($Live) { & "$PSScriptRoot/test-horses.ps1" -Live -SkipContact -Equines }
