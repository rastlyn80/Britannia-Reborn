param([string]$Godot,[switch]$Synthetic,[switch]$SecondClient,[switch]$Compatibility,[switch]$ReferencePatch)
$ErrorActionPreference = 'Stop'
if (!(Test-Path "$PSScriptRoot\Viewer\world.json")) { & "$PSScriptRoot\build.ps1" }
if (!$Godot) {
  $Godot = (Get-ChildItem "$PSScriptRoot\.tools\godot\*win64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
  if (!$Godot) { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
$env:APPDATA = Join-Path $PSScriptRoot '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
& $Godot --headless --path "$PSScriptRoot\Viewer" --editor --import
if ($LASTEXITCODE) { throw 'Art import failed; run scripts/verify.ps1 for diagnostics' }
$renderArgs = @()
if ($Compatibility) { $renderArgs = @('--rendering-method','gl_compatibility') }
$local = Join-Path $PSScriptRoot 'Viewer\local-world.json'
$play = Join-Path $PSScriptRoot 'Viewer\play-world.json'
if (Test-Path "$PSScriptRoot\Server\credentials.local.json") {
  $credentials = Get-Content "$PSScriptRoot\Server\credentials.local.json" -Raw | ConvertFrom-Json
  $env:UO_DEV_USER = $credentials.username
  if ($SecondClient) { $env:UO_DEV_USER += '2' }
  $env:UO_DEV_PASSWORD = $credentials.password
}
try {
  if ($Synthetic) { & $Godot @renderArgs --path "$PSScriptRoot\Viewer" -- '--world=res://world.json' }
  elseif (!$ReferencePatch) {
    if (!(Test-Path "$PSScriptRoot/outputs/britain/atlas.json")) { & "$PSScriptRoot/scripts/prepare-britain.ps1" }
    & "$PSScriptRoot/scripts/bake-britain.ps1"
    & $Godot @renderArgs --path "$PSScriptRoot/Viewer" -- --city
  }
  elseif (Test-Path $play) { & $Godot @renderArgs --path "$PSScriptRoot\Viewer" -- "--world=$play" }
  elseif (Test-Path $local) { & $Godot @renderArgs --path "$PSScriptRoot\Viewer" -- "--world=$local" }
  else { & $Godot @renderArgs --path "$PSScriptRoot\Viewer" }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
