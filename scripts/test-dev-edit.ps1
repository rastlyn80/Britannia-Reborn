# Developer edit checks. Offline: server session logic (dotnet) and client
# overlay/protocol (headless Godot; -Gpu also runs byte-level batch checks with
# a renderer). -Live adds the two-client session against the running local
# server with the development accounts; -Mark leaves a restart marker and
# -VerifyMarker checks it after a graceful server restart.
param([switch]$Live,[switch]$Gpu,[switch]$Mark,[switch]$VerifyMarker)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
if (!$VerifyMarker) {
 # Run from the test folder so its own global.json (server SDK) applies.
 Push-Location "$root/Server/PreviewTools.Tests"
 try { & "$root/.tools/dotnet-server/dotnet.exe" run -c Release }
 finally { Pop-Location }
 if ($LASTEXITCODE) { throw 'Developer edit session tests failed' }
 & $godot --headless --path "$root/Viewer" --script res://DevEdit/DevEditTests.gd
 if ($LASTEXITCODE) { throw 'Developer edit client tests failed' }
 # Committed overrides through the real converter (owned data; about a minute).
 if (Test-Path "$root/outputs/britain/atlas.json") {
  & $godot --headless --path "$root/Viewer" --script res://DevEdit/DevEditCommitTests.gd -- --classic-britain
  if ($LASTEXITCODE) { throw 'Committed override converter tests failed' }
 }
 if ($Gpu) {
  & $godot --path "$root/Viewer" --script res://DevEdit/DevEditTests.gd
  if ($LASTEXITCODE) { throw 'Developer edit GPU tests failed' }
 }
}
if ($Live -or $VerifyMarker) {
 $credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
 $env:UO_DEV_USER = $credentials.username
 $env:UO_DEV_PASSWORD = $credentials.password
 $extra = @()
 if ($Mark) { $extra += '--mark' }
 if ($VerifyMarker) { $extra += '--verify-marker' }
 try {
  & $godot --headless --path "$root/Viewer" --script res://DevEdit/DevEditLive.gd -- @extra
  if ($LASTEXITCODE) { throw 'Live developer edit session check failed' }
 } finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
}
