param([int]$Body=0xD8,[switch]$Capture,[switch]$Validate,[switch]$MaterialTest,[switch]$Live)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
if ($Validate) {& $godot --headless --path "$root/Viewer" --script res://Presentation/BovineTests.gd; if ($LASTEXITCODE) {throw 'Bovine source/pose validation failed'};return}
if ($MaterialTest) {& $godot --path "$root/Viewer" --script res://Presentation/BovineAppearanceTests.gd; if ($LASTEXITCODE) {throw 'Bovine rendered visibility/dye validation failed'};return}
if ($Live) {& "$PSScriptRoot/test-horses.ps1" -Live -SkipContact -Bovines;return}
$options=@("--body=$Body")
if ($Capture) {$options+='--capture-dir='+(Join-Path $root "outputs/bovines/$Body")}
& $godot --path "$root/Viewer" --script res://Presentation/BovineReview.gd -- @options
if ($LASTEXITCODE) {throw 'Bovine review failed'}
