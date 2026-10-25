param([string]$Godot,[switch]$Synthetic)
$ErrorActionPreference = 'Stop'
if (!(Test-Path "$PSScriptRoot\Viewer\world.json")) { & "$PSScriptRoot\build.ps1" }
if (!$Godot) {
  $Godot = (Get-ChildItem "$PSScriptRoot\.tools\godot\*win64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
  if (!$Godot) { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
$env:APPDATA = Join-Path $PSScriptRoot '.godot-user'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$local = Join-Path $PSScriptRoot 'Viewer\local-world.json'
if (!$Synthetic -and (Test-Path $local)) { & $Godot --path "$PSScriptRoot\Viewer" -- "--world=$local" }
else { & $Godot --path "$PSScriptRoot\Viewer" }
