param([string]$DataDir, [string]$Dataset)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (!$DataDir -and (Test-Path "$root/Server/runtime/Configuration/modernuo.json")) {
  $config=Get-Content "$root/Server/runtime/Configuration/modernuo.json" -Raw | ConvertFrom-Json
  if ($config.dataDirectories) { $DataDir=@($config.dataDirectories)[0] }
}
if (!$DataDir) { $DataDir="$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic" }
$env:APPDATA=Join-Path $root '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$extra=@("--data=$DataDir")
if ($Dataset) { $extra+="--dataset=$Dataset" }
& $godot --headless --path "$root/Viewer" --script res://Presentation/BakeMinimap.gd -- @extra
if ($LASTEXITCODE) { throw 'Local minimap conversion failed' }
