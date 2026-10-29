# -Region britain-trinsic -Route trinsic walks the road from Britain to Trinsic and back.
param([switch]$Compatibility,[string]$Region,[string]$Route)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$mode=@()
if ($Compatibility) { $mode=@('--rendering-method','gl_compatibility') }
$extra=@()
if ($Region) { $extra+="--region=$Region" }
if ($Route) { $extra+="--route=$Route" }
& $godot @mode --path "$root/Viewer" --script res://Presentation/StreamingCheck.gd -- --city --hide-ui @extra
if ($LASTEXITCODE) { throw 'Prepared streaming stress test failed' }
