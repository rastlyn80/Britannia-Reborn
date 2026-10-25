param([string]$Godot,[switch]$Synthetic,[switch]$SecondClient)
$ErrorActionPreference = 'Stop'
if (!(Test-Path "$PSScriptRoot\Viewer\world.json")) { & "$PSScriptRoot\build.ps1" }
if (!$Godot) {
  $Godot = (Get-ChildItem "$PSScriptRoot\.tools\godot\*win64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
  if (!$Godot) { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
$env:APPDATA = Join-Path $PSScriptRoot '.godot-user'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$local = Join-Path $PSScriptRoot 'Viewer\local-world.json'
$play = Join-Path $PSScriptRoot 'Viewer\play-world.json'
if (Test-Path "$PSScriptRoot\Server\credentials.local.json") {
  $credentials = Get-Content "$PSScriptRoot\Server\credentials.local.json" -Raw | ConvertFrom-Json
  $env:UO_DEV_USER = $credentials.username
  if ($SecondClient) { $env:UO_DEV_USER += '2' }
  $env:UO_DEV_PASSWORD = $credentials.password
}
try {
  if ($Synthetic) { & $Godot --path "$PSScriptRoot\Viewer" -- '--world=res://world.json' }
  elseif (Test-Path $play) { & $Godot --path "$PSScriptRoot\Viewer" -- "--world=$play" }
  elseif (Test-Path $local) { & $Godot --path "$PSScriptRoot\Viewer" -- "--world=$local" }
  else { & $Godot --path "$PSScriptRoot\Viewer" }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
