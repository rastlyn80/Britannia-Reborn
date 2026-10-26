param([switch]$Compatibility)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$mode=@()
if ($Compatibility) { $mode=@('--rendering-method','gl_compatibility') }
& $godot @mode --path "$root/Viewer" --script res://Presentation/StreamingCheck.gd -- --city --hide-ui
if ($LASTEXITCODE) { throw 'Prepared streaming stress test failed' }
