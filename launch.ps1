param([string]$Godot,[switch]$Synthetic,[switch]$SecondClient,[switch]$Compatibility,[switch]$ReferencePatch,[string]$Region)
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
# Sound and music from the owner's install: a local index (scripts/prepare-audio.py).
if (!(Test-Path "$PSScriptRoot\Viewer\local-audio\index.json") -and (Get-Command python -ErrorAction SilentlyContinue)) { python "$PSScriptRoot\scripts\prepare-audio.py" }
# Wearable layers (which paperdoll slot an item goes to), scripts/prepare-wearables.py.
if (!(Test-Path "$PSScriptRoot\Viewer\local-items\wearables.json") -and (Get-Command python -ErrorAction SilentlyContinue)) { python "$PSScriptRoot\scripts\prepare-wearables.py" }
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
  elseif ($Region) {
    # A larger streamed region (scripts/prepare-region.ps1); only its modern bake exists so far.
    $dataset = Join-Path $PSScriptRoot "outputs/$Region"
    if (!(Test-Path "$dataset/atlas.json")) { throw "Region $Region is not prepared; run scripts/prepare-region.ps1 first" }
    & "$PSScriptRoot/scripts/prepare-streaming.ps1" -Dataset $dataset -Modern
    & "$PSScriptRoot/scripts/prepare-minimap.ps1" -Dataset $dataset
    & $Godot @renderArgs --path "$PSScriptRoot/Viewer" -- --city --modern-britain "--region=$Region" --front-end
  }
  elseif (!$ReferencePatch) {
    if (!(Test-Path "$PSScriptRoot/outputs/britain/atlas.json")) { & "$PSScriptRoot/scripts/prepare-britain.ps1" }
    & "$PSScriptRoot/scripts/prepare-streaming.ps1"
    & "$PSScriptRoot/scripts/prepare-minimap.ps1"
    # --front-end: sign in on the front-end stage; districts load at the character.
    & $Godot @renderArgs --path "$PSScriptRoot/Viewer" -- --city --front-end
  }
  elseif (Test-Path $play) { & $Godot @renderArgs --path "$PSScriptRoot\Viewer" -- "--world=$play" }
  elseif (Test-Path $local) { & $Godot @renderArgs --path "$PSScriptRoot\Viewer" -- "--world=$local" }
  else { & $Godot @renderArgs --path "$PSScriptRoot\Viewer" }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
