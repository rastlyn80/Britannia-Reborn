param([switch]$Multiplayer,[switch]$Visual,[switch]$Restore)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root\.tools\godot\*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$credentials = Get-Content "$root\Server\credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
try {
  $scene = if ($Restore) { 'res://Network/RestoreBritain.gd' } elseif ($Visual) { 'res://Network/PlayVisual.gd' } elseif ($Multiplayer) { 'res://Network/MultiplayerSmoke.gd' } else { 'res://Network/PlaySmoke.gd' }
  if ($Visual) {
    $env:UO_PLAY_SCREENSHOT = Join-Path $root 'outputs\validation\playable.png'
    & $godot --path "$root\Viewer" --script $scene
  } else { & $godot --headless --path "$root\Viewer" --script $scene }
  if ($LASTEXITCODE) { throw 'Play smoke failed' }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD,Env:\UO_PLAY_SCREENSHOT -ErrorAction SilentlyContinue }
